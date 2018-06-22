

remove_satellite_from_master() {

  log_info "remove myself from my master '${ICINGA2_MASTER}'"

  curl_opts=$(curl_opts)

  # remove myself from master
  #
  code=$(curl \
    ${curl_opts} \
    --request DELETE \
    https://${ICINGA2_MASTER}:5665/v1/objects/hosts/$(hostname -f)?cascade=1 )
}

add_satellite_to_master() {

  [[ "${ADD_SATELLITE_TO_MASTER}" = "false" ]] && return

  # helper function to create json for the curl commando below
  #
  api_satellite_host() {
    fqdn="$(hostname -f)"
    ip="$(hostname -i)"
cat << EOF
{
  "templates": [ "satellite-host" ],
  "attrs": {
    "vars.os": "Docker",
    "vars.remote_endpoint": "${fqdn}",
    "vars.satellite": "true",
    "max_check_attempts": "2",
    "check_interval": "30",
    "retry_interval": "10",
    "enable_notifications": true,
    "zone": "${fqdn}",
    "command_endpoint": "${fqdn}",
    "groups": ["icinga-satellites"]
  }
}
EOF
  }

  . /init/wait_for/icinga_master.sh

  curl_opts=$(curl_opts)

  # first, check if we already added!
  #
  code=$(curl \
    ${curl_opts} \
    --header "Accept: application/json" \
    --request GET \
    https://${ICINGA2_MASTER}:5665/v1/objects/hosts/$(hostname -f))

  if [[ $? -eq 0 ]]
  then

    status=$(echo "${code}" | jq --raw-output '.error' 2> /dev/null)
    message=$(echo "${code}" | jq --raw-output '.status' 2> /dev/null)

#    log_info "${status}"
#    log_info "${message}"

    # echo '{"error":404.0,"status":"No objects found."}'
    if [[ "${status}" = "404" ]]
    then

      # add myself as host
      #
      log_info "add myself to my master '${ICINGA2_MASTER}'"

      code=$(curl \
        ${curl_opts} \
        --header "Accept: application/json" \
        --request PUT \
        --data "$(api_satellite_host)" \
        https://${ICINGA2_MASTER}:5665/v1/objects/hosts/$(hostname -f))

#       log_info "${code}"

      if [[ $? -eq 0 ]]
      then
        status=$(echo "${code}" | jq --raw-output '.results[].code' 2> /dev/null)
        message=$(echo "${code}" | jq --raw-output '.results[].status' 2> /dev/null)

        log_info "${message}"
      else
        status=$(echo "${code}" | jq --raw-output '.results[].code' 2> /dev/null)
        message=$(echo "${code}" | jq --raw-output '.results[].status' 2> /dev/null)

        log_error "${message}"

        add_satellite_to_master
      fi
    else

      log_info "update host"
      log_info "missing implementation"
    fi
  else
    :
  fi
}


restart_master() {

  sleep $(random)s

  . /init/wait_for/icinga_master.sh

  # restart the master to activate the zone
  #
  log_info "restart the master '${ICINGA2_MASTER}' to activate the zone"
  code=$(curl \
    --user ${CERT_SERVICE_API_USER}:${CERT_SERVICE_API_PASSWORD} \
    --silent \
    --location \
    --header 'Accept: application/json' \
    --request POST \
    --insecure \
    https://${ICINGA2_MASTER}:5665/v1/actions/restart-process )

  if [[ $? -gt 0 ]]
  then
    status=$(echo "${code}" | jq --raw-output '.results[].code' 2> /dev/null)
    message=$(echo "${code}" | jq --raw-output '.results[].status' 2> /dev/null)

    log_error "${code}"
    log_error "${message}"
  fi
}


endpoint_configuration() {

  log_info "configure our endpoint"

  zones_file="/etc/icinga2/zones.conf"
  backup_zones_file="${ICINGA2_LIB_DIRECTORY}/backup/zones.conf"

  hostname_f=$(hostname -f)
  api_endpoint="${ICINGA2_LIB_DIRECTORY}/api/zones/${hostname_f}/_etc/${hostname_f}.conf"
  ca_file="${ICINGA2_LIB_DIRECTORY}/certs/ca.crt"

  # restore zone backup
  #
  if [[ -f ${backup_zones_file} ]]
  then
    log_info "restore old zones.conf"

    cp ${backup_zones_file} ${zones_file}

    master_json="${ICINGA2_LIB_DIRECTORY}/backup/sign_${HOSTNAME}.json"

    if [[ -f ${master_json} ]]
    then
      message=$(jq --raw-output .message ${master_json} 2> /dev/null)
      master_name=$(jq --raw-output .master_name ${master_json} 2> /dev/null)
      master_ip=$(jq --raw-output .master_ip ${master_json} 2> /dev/null)

      log_info "use remote master name '${master_name}'"

      # locate the Endpoint and the Zone for our Master and replace the original
      # entrys with the new one
      sed -i \
        -e 's/^\(object Endpoint\) "[^"]*"/\1 \"'$master_name'\"/' \
        -e 's/\(\[\) "[^"]*" \(\]\)/\1 \"'$master_name'\" \2/' \
      ${zones_file}
    fi
  fi

  if [[ $(grep -c "initial zones.conf" ${zones_file} ) -eq 1 ]]
  then
    log_info "first run"

    # first run
    #
    # remove default endpoint and zone configuration for 'NodeName' / 'ZoneName'
    #
    sed -i \
      -e '/^object Endpoint NodeName.*/d' \
      -e '/^object Zone ZoneName.*/d' \
      ${zones_file}

    # add our real icinga master
    #
    cat << EOF >> ${zones_file}
/** added Endpoint for icinga2-master '${ICINGA2_MASTER}' - $(date) */
/* the following line specifies that the client connects to the master and not vice versa */
object Endpoint "${ICINGA2_MASTER}" { host = "${ICINGA2_MASTER}" ; port = "5665" }
object Zone "master" { endpoints = [ "${ICINGA2_MASTER}" ] }

/* endpoint for this satellite */
object Endpoint NodeName { host = NodeName }
object Zone ZoneName { endpoints = [ NodeName ] }
EOF
    # remove the initial keyword
    #
    sed -i \
      -e '/^ \* initial zones.conf/d' \
      ${zones_file}
  fi

  if [[ -e ${api_endpoint} ]]
  then
    log_info "endpoint configuration from our master detected"

    # the API endpoint from our master
    # see into '/etc/icinga2/constants.conf':
    #   const NodeName = "$HOSTNAME"
    #
    # when the ${api_endpoint} file exists, the definition of
    #  'Endpoint NodeName' are double!
    # we remove this definition from the static config file
    log_info "  remove the static endpoint config"
    sed -i \
      -e '/^object Endpoint NodeName.*/d' \
      ${zones_file}

    # we must also replace the zone configuration
    # with our icinga-master as parent to report checks
    log_info "  replace the static zone config"
    sed -i \
      -e 's|^object Zone ZoneName.*}$|object Zone ZoneName { endpoints = [ NodeName ]; parent = "master" }|g' \
      ${zones_file}
  fi

  if [[ -e ${ca_file} ]]
  then
    log_info "CA from our master replicated"

    # TODO
    # detect the Endpoint for this zone
    if [[ -f ${api_endpoint} ]]
    then
      log_info "  endpoint also replicated"

      # we must also replace the zone configuration
      # with our icinga-master as parent to report checks
      log_info "  replace the static zone config"
      sed -i \
        -e 's|^object Zone ZoneName.*}$|object Zone ZoneName { endpoints = [ NodeName ]; parent = "master" }|g' \
        ${zones_file}
    fi
  fi

  # finaly, we create the backup
  #
  log_info "create backup of our zones.conf"
  cp ${zones_file} ${backup_zones_file}
}


request_certificate_from_master() {

  # we have a certificate
  # restore our own zone configuration
  # otherwise, we can't communication with the master
  #
  if ( [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ]] && [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt ]] )
  then
    log_info "i found a cert and key file"
    :
  else
    log_info "start node wizard to create an certificate"

    # no certificate found
    # use the node wizard to create a valid certificate request
    #
    expect /init/node-wizard.expect 1> /dev/null

    if [[ $? -gt 0 ]]
    then
      log_error "the node wizard had an error! :("
      exit 1
    fi

    sleep 4s

    # and now we have to ask our master to confirm this certificate
    #
    log_info "ask our cert-service to sign our certifiacte"

    . /init/wait_for/cert_service.sh

    code=$(curl \
      --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --insecure \
      --location \
      --request GET \
      --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
      --header "X-API-PASSWORD: ${CERT_SERVICE_API_PASSWORD}" \
      --write-out "%{http_code}\n" \
      --output /tmp/sign_${HOSTNAME}.json \
      http://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/sign/${HOSTNAME})

    if ( [[ $? -eq 0 ]] && [[ ${code} == 200 ]] )
    then
      message=$(jq --raw-output .message /tmp/sign_${HOSTNAME}.json 2> /dev/null)
      master_name=$(jq --raw-output .master_name /tmp/sign_${HOSTNAME}.json 2> /dev/null)
      master_ip=$(jq --raw-output .master_ip /tmp/sign_${HOSTNAME}.json 2> /dev/null)

      mv /tmp/sign_${HOSTNAME}.json ${ICINGA2_LIB_DIRECTORY}/backup/

      log_info "${message}"
      log_info "  - ${master_name}"
      log_info "  - ${master_ip}"

      sleep 5s

      RESTART_NEEDED="true"
    else
      status=$(echo "${code}" | jq --raw-output .status 2> /dev/null)
      message=$(echo "${code}" | jq --raw-output .message 2> /dev/null)

      log_error "${message}"

      # TODO
      # wat nu?
    fi

    endpoint_configuration
  fi
}


# configure a icinga2 satellite instance
#
configure_icinga2_satellite() {

  # TODO check this!
  #
  export ICINGA2_SATELLITE=true

  # ONLY THE MASTER CREATES NOTIFICATIONS!
  #
  [[ -e /etc/icinga2/features-enabled/notification.conf ]] && disable_icinga_feature notification

  # all communications between master and satellite needs the API feature
  #
  enable_icinga_feature api

  # rename the hosts.conf and service.conf
  # this both comes now from the master
  # yeah ... distributed monitoring rocks!
  #
  for file in hosts.conf services.conf
  do
    [[ -f /etc/icinga2/conf.d/${file} ]] && mv /etc/icinga2/conf.d/${file} /etc/icinga2/conf.d/${file}-SAVE
  done

  if [[ ! -f ${ICINGA2_CERT_DIRECTORY}/ca.crt ]]
  then
    rm -rfv ${ICINGA2_CERT_DIRECTORY}/*
  fi

  # we have a certificate
  # validate this against our icinga-master
  #
  if ( [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ]] && [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt ]] )
  then
    validate_local_ca
    # create the certificate pem for later use
    #
    create_certificate_pem
  fi

  # endpoint configuration are tricky
  #  - stage #1
  #    - we need our icinga-master as endpoint for connects
  #    - we need also our endpoint *AND* zone configuration to create an valid certificate
  #  - stage #2
  #    - after the exchange of certificates, we don't need our endpoint configuration,
  #      this comes now from the master
  #
  endpoint_configuration


  log_info "waiting for our cert-service on '${CERT_SERVICE_SERVER}' to come up"
  . /init/wait_for/cert_service.sh

  log_info "waiting for our icinga master '${ICINGA2_MASTER}' to come up"
  . /init/wait_for/icinga_master.sh

  request_certificate_from_master

  [[ -f /etc/icinga2/satellite.d/services.conf ]] && cp /etc/icinga2/satellite.d/services.conf /etc/icinga2/conf.d/
  [[ -f /etc/icinga2/satellite.d/commands.conf ]] && cp /etc/icinga2/satellite.d/commands.conf /etc/icinga2/conf.d/satellite_commands.conf

  # REALLY BAD HACK ..
  # copy the inline templates direct into the API path
  #
  if [[ ! -d /var/lib/icinga2/api/zones/global-templates/_etc/ ]]
  then
    mkdir -p /var/lib/icinga2/api/zones/global-templates/_etc/
    cp -a /etc/icinga2/master.d/templates_services.conf /var/lib/icinga2/api/zones/global-templates/_etc/
  fi

  correct_rights

  # wee need an restart?
  #
  if [[ "${RESTART_NEEDED}" = "true" ]]
  then
    restart_master

    sed -i \
      -e 's|^object Zone ZoneName.*}$|object Zone ZoneName { endpoints = [ NodeName ]; parent = "master" }|g' \
      /etc/icinga2/zones.conf

    log_warn "waiting for reconnecting and certifiacte signing"

    . /init/wait_for/icinga_master.sh

    # start icinga to retrieve the data from our master
    # the zone watcher will kill this instance, when all datas ready!
    #
    nohup /init/runtime/zone_watcher.sh > /dev/stdout 2>&1 &
    sleep 2s
    start_icinga
  fi

  # test the configuration
  #
  /usr/sbin/icinga2 \
    daemon \
    --validate

  # validation are not successful
  #
  if [[ $? -gt 0 ]]
  then
    log_error "the validation of our configuration was not successful."
    exit 1
  fi

  if [[ -e /tmp/add_host ]] && [[ ! -e /tmp/final ]]
  then
    touch /tmp/final

    add_satellite_to_master

    sleep 10s
  fi
}

configure_icinga2_satellite
