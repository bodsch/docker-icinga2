

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
    --request GET \
    --header "Accept: application/json" \
    https://${ICINGA2_MASTER}:5665/v1/objects/hosts/$(hostname -f))

  result="${?}"

  if [[ ${result} -eq 0 ]]
  then

    status=$(echo "${code}" | jq --raw-output '.error' 2> /dev/null)
    msg=$(echo "${code}" | jq --raw-output '.status' 2> /dev/null)

    if [[ "${status}" = "200" ]]
    then
      # object exists ...
      # is all fine

      return
    fi

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

      if [[ ${result} -eq 0 ]] && [[ ${code} = 200 ]]
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

        touch /tmp/final
      else
        status=$(echo "${code}" | jq --raw-output '.results[].code' 2> /dev/null)
        msg=$(echo "${code}" | jq --raw-output '.results[].status' 2> /dev/null)

        log_error "${msg}"

        add_satellite_to_master
      fi
    fi

  else
    log_error "'${code}'"
    :
  fi

  touch /tmp/final
  sleep 10s
}

# ----------------------------------------------------------------------------------------

certificate_with_ticket() {

  [[ -d ${ICINGA2_CERT_DIRECTORY} ]] || mkdir -p ${ICINGA2_CERT_DIRECTORY}

  chmod a+w ${ICINGA2_CERT_DIRECTORY}

  if [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ]] && [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt ]]
  then
    return
  fi

  # create an ticket on the master via:
  #  icinga2 pki ticket --cn ${HOSTNAME}

  . /init/wait_for/cert_service.sh

  [[ "${DEBUG}" = "true" ]] && log_debug "ask for an PKI ticket"
  ticket=$(curl \
    --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
    --silent \
    --location \
    --insecure \
    --request GET \
    --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
    --header "X-API-PASSWORD: ${CERT_SERVICE_API_PASSWORD}" \
    --header "X-API-HOSTNAME: ${HOSTNAME}" \
    --header "X-API-TICKETSALT: ${TICKET_SALT}" \
    "${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}/v2/ticket/${HOSTNAME}")

  # the following commands are copied out of the icinga2-documentation
  [[ "${DEBUG}" = "true" ]] && log_debug "pki new-cert"
  icinga2 pki new-cert \
    --log-level ${ICINGA2_LOGLEVEL} \
    --cn ${HOSTNAME} \
    --key ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key \
    --cert ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt

  [[ "${DEBUG}" = "true" ]] && log_debug "pki save-cert"
  icinga2 pki save-cert \
    --log-level ${ICINGA2_LOGLEVEL} \
    --trustedcert ${ICINGA2_CERT_DIRECTORY}/trusted-master.crt \
    --host ${ICINGA2_MASTER}

  . /init/wait_for/icinga_master.sh

  [[ "${DEBUG}" = "true" ]] && log_debug "pki request"
  icinga2 pki request \
    --log-level ${ICINGA2_LOGLEVEL} \
    --host ${ICINGA2_MASTER} \
    --ticket ${ticket} \
    --key ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key \
    --cert ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt \
    --trustedcert ${ICINGA2_CERT_DIRECTORY}/trusted-master.crt \
    --ca ${ICINGA2_CERT_DIRECTORY}/ca.crt

  [[ "${DEBUG}" = "true" ]] && log_debug "node setup"
  # --disable-confd \
  icinga2 node setup \
    --log-level ${ICINGA2_LOGLEVEL} \
    --accept-config \
    --accept-commands \
    --cn ${HOSTNAME} \
    --zone ${HOSTNAME} \
    --endpoint ${ICINGA2_MASTER} \
    --parent_host ${ICINGA2_MASTER} \
    --parent_zone master \
    --ticket ${ticket} \
    --trustedcert ${ICINGA2_CERT_DIRECTORY}/trusted-master.crt

  date="$(date "+%Y-%m-%d %H:%M:%S")"
  timestamp="$(date "+%s")"

  cat << EOF > ${ICINGA2_LIB_DIRECTORY}/backup/sign_${HOSTNAME}.json
{
  "status": 200,
  "ticket": "${ticket}",
  "message": "PKI for ${HOSTNAME}",
  "master_name": "${ICINGA2_MASTER}",
  "master_ip": "",
  "date": "${date}",
  "timestamp": ${timestamp}
}
EOF

  [[ "${DEBUG}" = "true" ]] && log_debug "create zones.conf"
  cat << EOF > /etc/icinga2/zones.conf
/*
 * Generated by Icinga 2 node setup commands on ${date}
 * modified for a docker run
 * The required 'NodeName' are defined in constants.conf.
 */

/** added Endpoint for icinga2-master '${ICINGA2_MASTER}' - $(date)
 * my master
 * the following line specifies that the client connects to the master and not vice versa
 */
object Endpoint "${ICINGA2_MASTER}" { host = "${ICINGA2_MASTER}" ; port = "5665" }
object Zone "master" { endpoints = [ "${ICINGA2_MASTER}" ] }

/* endpoint for this satellite */
object Endpoint NodeName { host = NodeName }
object Zone ZoneName { endpoints = [ NodeName ] }

object Zone "global-templates" { global = true }
object Zone "director-global"  { global = true }

EOF

  [[ "${DEBUG}" = "true" ]] && log_debug "enable our endpoint"
  code=$(curl \
    --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
    --silent \
    --location \
    --insecure \
    --request GET \
    --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
    --header "X-API-PASSWORD: ${CERT_SERVICE_API_PASSWORD}" \
    --header "X-API-HOSTNAME: ${HOSTNAME}" \
    --header "X-API-TICKETSALT: ${TICKET_SALT}" \
    "${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}/v2/enable_endpoint/${HOSTNAME}")

  [[ "${DEBUG}" = "true" ]] && log_debug "code '${code}'"

  RESTART_NEEDED="true"
}


get_ca_file() {

  log_info "download master CA"

  ca_file="${ICINGA2_LIB_DIRECTORY}/certs/ca.crt"

  code=$(curl \
    --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
    --silent \
    --location \
    --insecure \
    --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
    --header "X-API-PASSWORD: ${CERT_SERVICE_API_PASSWORD}" \
    --header "X-API-HOSTNAME: ${HOSTNAME}" \
    --header "X-API-TICKETSALT: ${TICKET_SALT}" \
    --write-out "%{http_code}\n" \
    --output ${ca_file} \
    ${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/master-ca)

  result=${?}

  [[ "${DEBUG}" = "true" ]] && log_debug "get_ca_file: '${code}'"
}


restart_master() {

  sleep $(random)s

  . /init/wait_for/icinga_master.sh

  curl_opts=$(curl_opts)

  # restart the master to activate the zone
  #
  log_info "send a restart-process to our the master '${ICINGA2_MASTER}' to activate our zone"
  code=$(curl \
    ${curl_opts} \
    --header 'Accept: application/json' \
    --request POST \
    https://${ICINGA2_MASTER}:5665/v1/actions/restart-process)
#    https://${ICINGA2_MASTER}:5665/v1/actions/shutdown-process)

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
    log_info "  restore old zones.conf"
    cp ${backup_zones_file} ${zones_file}

    master_json="${ICINGA2_LIB_DIRECTORY}/backup/sign_${HOSTNAME}.json"

    if [[ -f ${master_json} ]]
    then
      msg=$(jq --raw-output .message ${master_json} 2> /dev/null)
      master_name=$(jq --raw-output .master_name ${master_json} 2> /dev/null)
      master_ip=$(jq --raw-output .master_ip ${master_json} 2> /dev/null)

      log_info "  use remote master name '${master_name}'"

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
    log_info "  first run"

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
    log_info "  endpoint configuration from our master detected"

#     grep "object Endpoint NodeName" ${zones_file}
#     grep "object Zone ZoneName"     ${zones_file}

    # the API endpoint from our master
    # see into '/etc/icinga2/constants.conf':
    #   const NodeName = "$HOSTNAME"
    #
    # when the ${api_endpoint} file exists, the definition of
    #  'Endpoint NodeName' are double!
    # we remove this definition from the static config file
    if [[ $(grep -c -e "^object Endpoint NodeName" ${zones_file} ) -eq 1 ]]
    then
      log_info "  remove the static endpoint config"
      sed -i \
        -e '/^object Endpoint NodeName.*/d' \
        ${zones_file}
    fi

    # we must also replace the zone configuration
    # with our icinga-master as parent to report checks
    if [[ $(grep -c -e "^object Zone ZoneName" ${zones_file} ) -eq 1 ]]
    then
      log_info "  replace the static zone config"
      sed -i \
        -e 's|^object Zone ZoneName.*}$|object Zone ZoneName { endpoints = [ NodeName ]; parent = "master" }|g' \
        ${zones_file}
    fi
  fi


  # wait for the CA file
  if [[ ${first_run} = "false" ]]
  then
    max_retry=9
    retry=0

    log_info "  wait until the CA file has been replicated by the master"
    until ( [[ ${retry} -eq ${max_retry} ]] || [[ ${retry} -gt ${max_retry} ]] )
    do
      if [[ -e ${ca_file} ]]
      then
        log_info "  The CA was replicated by our master"

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

    #if [[ ! -e ${ca_file} ]]
    #then
    #  log_error "The CA was not replicated by our master."
    #
    #  log_debug "try fallback ..."
    #
    #  code=$(curl \
    #    --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
    #    --silent \
    #    --location \
    #    --insecure \
    #    --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
    #    --header "X-API-PASSWORD: ${CERT_SERVICE_API_PASSWORD}" \
    #    --write-out "%{http_code}\n" \
    #    --output ${ca_file} \
    #    ${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/sign/master-ca)
    #
    #  result=${?}
    #
    #  # exit 1
    #fi
  fi

  # finaly, we create the backup
  #
  log_info "  create backup of our zones.conf"

  #if [[ "${DEBUG}" = "true" ]]
  #then
  #  cat ${zones_file}
  #fi
  cp ${zones_file} ${backup_zones_file}

  log_info "  remove the static global-templates directory"
  [[ -d /etc/icinga2/zones.d/global-templates ]] && rm -rf /etc/icinga2/zones.d/global-templates

  log_info "  remove the static director-global directory"
  [[ -d /etc/icinga2/zones.d/director-global ]] && rm -rf /etc/icinga2/zones.d/director-global
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
  if [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ]] && [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt ]]
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

  certificate_with_ticket

  # the 'icinga2 node setup' has disabled the API feature.
  # but we need them for an healthcheck and our tests
  # ONLY FOR THIS. otherwise a satellite needs no enabled aüi feature :)
  #
  # communications between master and satellite needs the API feature
  #
  enable_icinga_feature api

  # endpoint configuration are tricky
  #  - stage #1
  #    - we need our icinga-master and endpoint for connects
  #    - we need also our endpoint *AND* zone configuration to create an valid certificate
  #  - stage #2
  #    - after the exchange of certificates, we don't need our endpoint configuration,
  #      this comes now from the master
  #
  endpoint_configuration

  sleep 5s

  [[ "${DEBUG}" = "true" ]] && log_debug "waiting for our cert-service on '${CERT_SERVICE_SERVER}' to come up"
  . /init/wait_for/cert_service.sh

  [[ "${DEBUG}" = "true" ]] && log_debug "waiting for our icinga master '${ICINGA2_MASTER}' to come up"
  . /init/wait_for/icinga_master.sh

  # 2018-08-22 disabled for replication tests
  #
  #[[ -f /etc/icinga2/satellite.d/services.conf ]] && cp /etc/icinga2/satellite.d/services.conf /etc/icinga2/conf.d/

  # with the 'certificate_with_ticket' function, the 'conf.d' directory is disabled and all configurations comes from the master
  # this part is then obsolete
  #
  [[ -f /etc/icinga2/satellite.d/commands.conf ]] && cp /etc/icinga2/satellite.d/commands.conf /etc/icinga2/conf.d/satellite_commands.conf

  # copy the inline templates direct into the API path
  # this file will be replaced truth the config sync
  #
  global_templates_directory="/var/lib/icinga2/api/zones/global-templates/_etc"
  if [[ ! -f "${global_templates_directory}/templates_services.conf" ]]
  then
    [[ ! -d "${global_templates_directory}" ]] && mkdir -p "${global_templates_directory}"
    cp -a /etc/icinga2/master.d/templates_services.conf "${global_templates_directory}"
  fi

  correct_rights

  if [[ "${DEBUG}" = "true" ]]
  then
    # kill the zone zone_debugger
    # not longer needed
    killall --verbose --signal KILL zone_debugger.sh
  fi

  # wee need an restart?
  #
  if [[ "${RESTART_NEEDED}" = "true" ]]
  then
    log_INFO "We need a restart of our master."
    restart_master

    log_info "remove our zone object from zones.conf"
    sed -i \
      -e 's|^object Zone ZoneName.*}$|object Zone ZoneName { endpoints = [ NodeName ]; parent = "master" }|g' \
      /etc/icinga2/zones.conf

# // object Endpoint NodeName { host = NodeName }
#    log_info "disable our Endpoint configuration from zones.conf"
#    sed -i \
#      -e "s/^\(object\ Endpoint\ NodeName .*\)/\/\/ \1/" \
#      /etc/icinga2/zones.conf

    log_info "waiting for reconnecting and certifiacte signing"
    . /init/wait_for/icinga_master.sh

    # start icinga to retrieve the data from our master
    # the zone watcher will kill this instance, when all datas ready!

    nohup /init/runtime/zone_watcher.sh > /dev/stdout 2>&1 &

    # sleep 2s
    #
    #log_debug "start initial icinga2 instance"
    #exec /usr/sbin/icinga2 \
    #  daemon \
    #  ${ICINGA2_PARAMS}

    # 2019-05-13
    # this is also in init/runtime/zone_watcher.sh defined
    #
    ## # signal for self-adding AFTER our restart
    ## touch /tmp/add_host
    ##
    ## # kill myself to finalize
    ## #
    ## pid=$(ps ax -o pid,args  | grep -v grep | grep icinga2 | grep daemon | awk '{print $1}')
    ##
    ## if [[ $(echo -e "${pid}" | wc -w) -gt 0 ]]
    ## then
    ##   log_INFO "now, we restart ourself for certificate and zone reloading."
    ##   [[ "${DEBUG}" = "true" ]] && log_debug " killall --verbose --signal HUP icinga2"
    ##   killall --verbose --signal HUP icinga2 > /dev/null 2> /dev/null
    ## fi
  fi

  # test the configuration
  #
  validate_icinga_config

  #if [[ -e /tmp/add_host ]] && [[ ! -e /tmp/final ]]
  if [[ ! -e /tmp/final ]]
  then
    add_satellite_to_master
  fi
}

configure_icinga2_satellite
