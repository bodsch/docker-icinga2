#!/bin/bash

# periodic check of the (satellite) CA file
# **this use the API from the icinga-cert-service!**
#
# when the CA file are not in  sync, we restart the container to
# getting a new certificate
#
# BE CAREFUL WITH THIS 'FEATURE'!
# IT'S JUST A FIX FOR A FAULTY USE.
#

. /init/output.sh
. /init/environment.sh

. /init/cert/certificate_handler.sh

log_info "start the CA validator for '${HOSTNAME}'"

while true
do
  # check the creation date of our certificate request against the
  # connected endpoints
  # (take a look in the test.sh line 112:125)
  #
  sign_file="${ICINGA2_LIB_DIRECTORY}/backup/sign_${HOSTNAME}.json"

  if [[ -f ${sign_file} ]]
  then
    ICINGA2_API_PORT=${ICINGA2_API_PORT:-5665}
    warn=300  #  5 minuten
    crit=600  # 10 minuten

    message=$(jq     --raw-output .message     ${sign_file} 2> /dev/null)
    master_name=$(jq --raw-output .master_name ${sign_file} 2> /dev/null)
    master_ip=$(jq   --raw-output .master_ip   ${sign_file} 2> /dev/null)
    date=$(jq        --raw-output .date        ${sign_file} 2> /dev/null)
    timestamp=$(jq   --raw-output .timestamp   ${sign_file} 2> /dev/null)
    checksum=$(jq    --raw-output .checksum    ${sign_file} 2> /dev/null)

    # timestamp must be in UTC!
    current_timestamp=$(date +%s)
    diff=$(( ${current_timestamp} - ${timestamp} ))
    diff_full=$(printf '%dh:%dm:%ds\n' $((${diff}/3600)) $((${diff}%3600/60)) $((${diff}%60)))

    curl_opts=
    if [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.pem ]]
    then
      curl_opts="${curl_opts} --capath ${ICINGA2_CERT_DIRECTORY}"
      curl_opts="${curl_opts} --cert   ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.pem"
      curl_opts="${curl_opts} --cacert ${ICINGA2_CERT_DIRECTORY}/ca.crt"
    else
      curl_opts="--insecure"
    fi

    code=$(curl \
      --user ${CERT_SERVICE_API_USER}:${CERT_SERVICE_API_PASSWORD} \
      --silent \
      ${curl_opts} \
      --header 'Accept: application/json' \
      https://${ICINGA2_MASTER}:${ICINGA2_API_PORT}/v1/status/ApiListener)

    result=${?}

    if [[ ${result} -eq 0 ]]
    then
      connected=$(echo "${code}" | jq --raw-output '.results[].status.api.conn_endpoints | join(",")' | grep -c ${HOSTNAME})

      if [[ ${connected} -eq 1 ]]
      then
        log_info "We are connected to our Master since ${diff_full} \m/"
      elif [[ ${connected} -eq 0 ]]
      then

        num_endpoints=$(echo "${code}"          | jq --raw-output ".results[].status.api.num_endpoints")
        num_conn_endpoints=$(echo "${code}"     | jq --raw-output ".results[].status.api.num_conn_endpoints")
        num_not_conn_endpoints=$(echo "${code}" | jq --raw-output ".results[].status.api.num_not_conn_endpoints")
        conn_endpoints=$(echo "${code}"         | jq --raw-output '.results[].status.api.conn_endpoints | join(",")')
        not_conn_endpoints=$(echo "${code}"     | jq --raw-output '.results[].status.api.not_conn_endpoints | join(",")')

        if [[ "${DEBUG}" = "true" ]]
        then
          log_debug "endpoints summary:"
          log_debug "totaly: '${num_endpoints}' / connected: '${num_conn_endpoints}' / not connected: '${num_not_conn_endpoints}'"
          log_debug "i'm connected: ${connected}"
          log_debug ""
          log_debug "connected endpoints: "
          log_debug "${conn_endpoints}"
          log_debug ""
          log_debug "not connected endpoints: "
          log_debug "${not_conn_endpoints}"
          log_debug ""
          log_debug "diff: '${diff}' | warn: '${warn}' / crit: '${crit}'"
          log_debug ""
        fi

        if [[ ${checksum} != null ]]
        then
          if [[ ${diff} -gt ${warn} ]] && [[ ${diff} -lt ${crit} ]]
          then
            log_warn "Our certificate request is already ${diff_full} old"
            log_warn "and we're not connected to the master yet."
            log_warn "This may be a major problem"
            log_warn "If this problem persists, the satellite will be reset and restarted."

          elif [[ ${diff} -gt ${crit} ]]
          then
            log_error "Our certificate request is already ${diff_full} old"
            log_error "and we're not connected to the master yet."
            log_error "That's a problem"
            log_INFO "This satellite will now be reset and restarted"

            pid=$(ps ax | grep icinga2 | grep -v grep | grep daemon | awk '{print $1}')
            [[ $(echo -e "${pid}" | wc -w) -gt 0 ]] && killall --verbose --signal HUP icinga2 > /dev/null 2> /dev/null

            exit 1
          fi
        fi
      else
        # DAS GEHT?
        :
      fi
    fi
  else
    log_error "i can't find the sign file '${sign_file}'"
    log_error "That's a problem"
    log_INFO "This satellite will now be reset and restarted"

    pid=$(ps ax | grep icinga2 | grep -v grep | grep daemon | awk '{print $1}')
    [[ $(echo -e "${pid}" | wc -w) -gt 0 ]] && killall --verbose --signal HUP icinga2 > /dev/null 2> /dev/null

    exit 1
  fi

  validate_local_ca

  if [[ ! -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ]]
  then
    log_error "The validation of our CA was not successful."
    log_error "That's a problem"
    log_INFO "This satellite will now be reset and restarted"

    rm -rf ${ICINGA2_CERT_DIRECTORY}/*

    pid=$(ps ax | grep icinga2 | grep -v grep | grep daemon | awk '{print $1}')
    [[ $(echo -e "${pid}" | wc -w) -gt 0 ]] && killall --verbose --signal HUP icinga2 > /dev/null 2> /dev/null

    exit 1
  fi

  sleep 5m
done
