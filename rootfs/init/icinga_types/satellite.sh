

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

  if [[ "${ADD_SATELLITE_TO_MASTER}" = false ]]
  then
    return
  fi

  # helper function to create json for the curl commando below
  #
  api_satellite_host() {

    fqdn="$(hostname -f)"
    short="$(hostname -s)"
    ip="$(hostname -i)"

    templates=()

    if [[ "${fqdn}" = "${short}" ]]
    then
      templates+=(
        "host_object_data_${short}.json"
        "host_object_data-${short}.json"
        "host_object_data.${short}.json"
      )
    else
      templates+=(
        "host_object_data_${fqdn}.json"
        "host_object_data_${short}.json"
        "host_object_data-${fqdn}.json"
        "host_object_data-${short}.json"
        "host_object_data.${fqdn}.json"
        "host_object_data.${short}.json"
      )
    fi

    templates+=("host_object_data.json")

    [[ "${DEBUG}" = "true" ]] && log_debug "possible templates are: '${templates[*]}'"

    template=

    for i in "${templates[@]}"
    do
      [[ "${DEBUG}" = "true" ]] && log_debug "look for template: '${i}'"

      if [[ -f "/import/${i}" ]]
      then
        template="/import/${i}"
        break
      fi
    done

    if [[ -z "${template}" ]]
    then

      log_info "no custom template found. use internal standard."

cat << EOF > "${ICINGA2_LIB_DIRECTORY}/backup/host_object_data.json"
{
  "templates": [ "satellite-host" ],
  "attrs": {
    "command_endpoint": "${fqdn}",
    "enable_notifications": true,
    "groups": ["icinga-satellites"],
    "max_check_attempts": "2",
    "check_interval": "30",
    "retry_interval": "10",
    "zone": "${fqdn}",
    "vars": {
      "os": "Docker",
      "remote_endpoint": "${fqdn}",
      "satellite": "true",
      "disks": {
        "disk /": {
          "disk_partitions": "/",
          "disk_exclude_type": [
            "none",
            "tmpfs",
            "sysfs",
            "proc",
            "configfs",
            "devtmpfs",
            "devfs",
            "mtmfs",
            "tracefs",
            "cgroup",
            "fuse.gvfsd-fuse",
            "fuse.gvfs-fuse-daemon",
            "fdescfs",
            "nsfs"
          ]
        }
      },
      "memory": "true"
    }
  }
}
EOF

    else

      log_info "use custom template '${template}'"

      cat "${template}" | \
      sed -e \
        "s|%FQDN%|${fqdn}|g" > "${ICINGA2_LIB_DIRECTORY}/backup/host_object_data.json"
    fi
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
    msg=$(echo "${code}" | jq --raw-output '.status' 2> /dev/null)

    # 404 stands for 'no data for ... found'
    #
    if [[ "${status}" = "404" ]]
    then

      # add myself as host
      #
      log_info "add myself to my master '${ICINGA2_MASTER}'"

      api_satellite_host

      # - validate json
      #
      check=$(cat \
        "${ICINGA2_LIB_DIRECTORY}/backup/host_object_data.json" | \
        jq . 2>&1)

      result=${?}

      if [[ ${result} -gt 0 ]]
      then
        log_error "The template file is not a valid json!"
        log_error "${check}"

        # parse output
        #
        # show an excerpt of the possible error
        line=$(echo "${check}" | awk -F 'line ' '{ print $2}' | awk -F ',' '{print $1}')
        start=$((${line} - 3))
        error=$(tail -n+${start} "${ICINGA2_LIB_DIRECTORY}/backup/host_object_data.json" | head -n5)

        while read -r line
        do
          log_error "  $line"
        done < <(echo "${error}")

        return
      fi
      #
      # - validate json

      code=$(curl \
        ${curl_opts} \
        --header "Accept: application/json" \
        --request PUT \
        --data @"${ICINGA2_LIB_DIRECTORY}/backup/host_object_data.json" \
        --write-out "%{http_code}\n" \
        --output "/tmp/import_host_object_data.json" \
        https://${ICINGA2_MASTER}:5665/v1/objects/hosts/$(hostname -f))

      result=${?}

      if [[ "${DEBUG}" = "true" ]]
      then
        log_debug "result for PUT request:"
        log_debug "result: '${result}' | code: '${code}'"
        log_debug "$(ls -lth /tmp/import_host_object_data.json)"

        cat /tmp/import_host_object_data.json
      fi

      if [[ ${result} -eq 0 ]]  && [[ ${code} == 200 ]]
      then
        error=$(jq   --raw-output '.error'  /tmp/import_host_object_data.json 2> /dev/null)

        if [ "${error}" != "null" ]
        then
          status=${error}
          msg=$(jq --raw-output '.status' /tmp/import_host_object_data.json 2> /dev/null)
        else
          error=$(jq   --raw-output '.results[].errors' /tmp/import_host_object_data.json 2> /dev/null)
          status=$(jq  --raw-output '.results[].code'   /tmp/import_host_object_data.json 2> /dev/null)
          msg=$(jq     --raw-output '.results[].status' /tmp/import_host_object_data.json 2> /dev/null)
        fi

        if [[ "${DEBUG}" = "true" ]]
        then
          log_debug "status : '${status}'"
          log_debug "error  : '${error}'"
          log_debug "msg    : '${msg}'"
        fi

        if [[ "${status}" = "200" ]]
        then
          log_info "successful .. ${msg}"

        elif [[ "${status}" = "400" ]]
        then
          log_error "has failed with code ${status}!"

          return

        elif [[ "${status}" = "500" ]]
        then
          log_error "has failed with code ${status}!"

          # damn an error!
          # possible wrong json?
          # error=$(echo "${code}" | jq --raw-output '.results[].errors' 2> /dev/null)

          # only the first 5 rows of error should displayed
          #
          while read -r line
          do
            log_error "  $line"
          done < <(echo "${error}" | jq --raw-output .[] | head -n5)

          return


        elif [[ "${status}" = "" ]]
        then
          log_warn "empty status"

        else
          log_debug "curl result code: '${result}'"
          log_info "result code '${status}' is currently not handled."
          log_info "please open an issue:"
          log_info "https://github.com/bodsch/docker-icinga2/issues"
        fi
#        touch /tmp/final
      else
        status=$(echo "${code}" | jq --raw-output '.results[].code' 2> /dev/null)
        msg=$(echo "${code}" | jq --raw-output '.results[].status' 2> /dev/null)

        log_error "${msg}"

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

  curl_opts=$(curl_opts)

  # restart the master to activate the zone
  #
  log_info "restart the master '${ICINGA2_MASTER}' to activate the zone"
  code=$(curl \
    ${curl_opts} \
    --header 'Accept: application/json' \
    --request POST \
    https://${ICINGA2_MASTER}:5665/v1/actions/shutdown-process)
##    https://${ICINGA2_MASTER}:5665/v1/actions/restart-process ) # <- since 2.9.1 not functional?

  if [[ $? -eq 0 ]]
  then
    status=$(echo "${code}" | jq --raw-output '.results[].code' 2> /dev/null)
    msg=$(echo "${code}" | jq --raw-output '.results[].status' 2> /dev/null)

    if [[ ${status} -eq 200 ]]
    then
      :
      # restart triggert
      sleep $(random)s
      . /init/wait_for/icinga_master.sh
    else
      log_debug "status: ${status}"
      if [[ ! -z "${code}" ]] && [[ ! -z "${msg}" ]]
      then
        log_error "${code}"
        log_error "${msg}"
      fi
    fi
  fi
}


endpoint_configuration() {

  log_info "configure our endpoint"

  local first_run="false"

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
      msg=$(jq --raw-output .message ${master_json} 2> /dev/null)
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
    first_run="true"
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


  # wait for the CA file
  if [[ ${first_run} = "false" ]]
  then
    max_retry=9
    retry=0

    log_info "wait until the CA file has been replicated by the master"
    until ( [[ ${retry} -eq ${max_retry} ]] || [[ ${retry} -gt ${max_retry} ]] )
    do
      if [[ -e ${ca_file} ]]
      then
        log_info "The CA was replicated by our master"

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

        break
      else
        retry=$((${retry} + 1))

        sleep 10s
      fi

    done

    if [[ ! -e ${ca_file} ]]
    then
      log_error "The CA was not replicated by our master."

      log_debug "try fallback ..."

      code=$(curl \
        --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
        --silent \
        --location \
        --insecure \
        --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
        --header "X-API-PASSWORD: ${CERT_SERVICE_API_PASSWORD}" \
        --write-out "%{http_code}\n" \
        --output ${ca_file} \
        ${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/sign/master-ca)

      result=${?}

      # exit 1
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
    :
  else
    # no certificate found
    # use the node wizard to create a valid certificate request
    #

    log_info "use the node wizard to create a valid certificate request"
    expect /init/node-wizard.expect 1> /dev/null

    result=${?}

    if [[ "${DEBUG}" = "true" ]]
    then
      log_debug "the result for the node-wizard was '${result}'"
    fi

    # after this, in /var/lib/icinga2/certs/ should be found this files:
    #  - ca.crt
    #  - $(hostname -f).key
    #  - $(hostname -f).crt
    #
    # these files are absolutly importand for the nexts steps
    # we can abort immediately, if it should come to mistakes.

    sleep 8s

    # check transfered certificate files
    #
    BREAK="false"
    for f in ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt ${ICINGA2_CERT_DIRECTORY}/ca.crt
    do
      if [[ -f ${f} ]]
      then
        log_info "file '${f}' exists!"
      else
        log_error "file '${f}' is missing!"
        BREAK="true"
      fi
    done

    if [[ ${BREAK} = "true" ]]
    then
      # hard exist
      rm -rfv ${ICINGA2_CERT_DIRECTORY}/*
      exit 1
    fi

    #if [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ]] && [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt ]] && [[ -f ${ICINGA2_CERT_DIRECTORY}/ca.crt ]]


    # and now we have to ask our master to confirm this certificate
    #
    log_info "ask our cert-service to sign our certifiacte"

    . /init/wait_for/cert_service.sh

    code=$(curl \
      --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --location \
      --insecure \
      --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
      --header "X-API-PASSWORD: ${CERT_SERVICE_API_PASSWORD}" \
      --write-out "%{http_code}\n" \
      --output /tmp/sign_${HOSTNAME}.json \
      ${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/sign/${HOSTNAME})

    result=${?}

    if [[ "${DEBUG}" = "true" ]]
    then
      log_debug "result for sign certificate:"
      log_debug "result: '${result}' | code: '${code}'"
      log_debug "$(ls -lth /tmp/sign_${HOSTNAME}.json)"
    fi

    if [[ ${result} -eq 0 ]]  && [[ ${code} == 200 ]]
    then
      msg=$(jq --raw-output .message /tmp/sign_${HOSTNAME}.json 2> /dev/null)
      master_name=$(jq --raw-output .master_name /tmp/sign_${HOSTNAME}.json 2> /dev/null)
      master_ip=$(jq --raw-output .master_ip /tmp/sign_${HOSTNAME}.json 2> /dev/null)

      if [[ "${master_name}" = null ]] || [[ "${master_ip}" = null ]]
      then
        log_error "${msg}"
        log_error "no valid data were transmitted by our icinga2 master."

        exit 1
      fi

      mv /tmp/sign_${HOSTNAME}.json ${ICINGA2_LIB_DIRECTORY}/backup/

      log_info "${msg}"
      if [[ "${DEBUG}" = "true" ]]
      then
        log_debug "  - ${master_name}"
        log_debug "  - ${master_ip}"
      fi

      sleep 5s

      RESTART_NEEDED="true"
    else
      status=$(echo "${code}" | jq --raw-output .status 2> /dev/null)
      msg=$(echo "${code}" | jq --raw-output .message 2> /dev/null)

      [[ "${DEBUG}" = "true" ]] && log_debug "${status}"

      log_error "curl result: '${result}'"
      log_error "${msg}"

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

  if [[ "${DEBUG}" = "true" ]]
  then
    nohup /init/runtime/zone_debugger.sh > /dev/stdout 2>&1 &
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

  # 2018-08-22 disabled for replication tests
  #
  #[[ -f /etc/icinga2/satellite.d/services.conf ]] && cp /etc/icinga2/satellite.d/services.conf /etc/icinga2/conf.d/
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
    log_INFO "We need a restart of our master."
    restart_master

    sed -i \
      -e 's|^object Zone ZoneName.*}$|object Zone ZoneName { endpoints = [ NodeName ]; parent = "master" }|g' \
      /etc/icinga2/zones.conf

    log_info "waiting for reconnecting and certifiacte signing"

    . /init/wait_for/icinga_master.sh

    if [[ "${DEBUG}" = "true" ]]
    then
      # kill the zone zone_debugger
      # not longer needed
      killall --verbose --signal KILL zone_debugger.sh
    fi

    # start icinga to retrieve the data from our master
    # the zone watcher will kill this instance, when all datas ready!
    #
    nohup /init/runtime/zone_watcher.sh > /dev/stdout 2>&1 &
    sleep 2s
    start_icinga
  fi

  # test the configuration
  #
  validate_icinga_config

  if [[ -e /tmp/add_host ]] && [[ ! -e /tmp/final ]]
  then
    add_satellite_to_master

    touch /tmp/final
    sleep 10s
  fi
}

configure_icinga2_satellite
