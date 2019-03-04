#!/bin/bash

# use inotify to detect changes in the ${monitored_directory} and sync
# changes to ${backup_directory}
# when a 'delete' event is triggerd, the file/directory will also removed
# from ${backup_directory}
#
# in this case, we need only a sync of all 'zones.*' files/directory
#

. /init/output.sh
. /init/environment.sh

log_info "start the satellite monitor"


while true
do
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
    --user "${CERT_SERVICE_API_USER}:${CERT_SERVICE_API_PASSWORD}" \
    --silent \
    "${curl_opts}" \
    --header 'Accept: application/json' \
    "https://localhost:5665/v1/status/ApiListener")

  result=${?}

  if [[ ${result} -eq 0 ]]
  then
      num_endpoints=$(echo "${code}"          | jq --raw-output ".results[].status.api.num_endpoints")
      num_conn_endpoints=$(echo "${code}"     | jq --raw-output ".results[].status.api.num_conn_endpoints")
      num_not_conn_endpoints=$(echo "${code}" | jq --raw-output ".results[].status.api.num_not_conn_endpoints")
      conn_endpoints=$(echo "${code}"         | jq --raw-output '.results[].status.api.conn_endpoints | join(",")')
      not_conn_endpoints=$(echo "${code}"     | jq --raw-output '.results[].status.api.not_conn_endpoints | join(",")')

#      if [[ "${DEBUG}" = "true" ]]
#      then
        log_debug "endpoints summary:"
        log_debug "totaly: '${num_endpoints}' / connected: '${num_conn_endpoints}' / not connected: '${num_not_conn_endpoints}'"
        #log_debug "i'm connected: ${connected}"
        log_debug ""
        log_debug "connected endpoints: "
        log_debug "${conn_endpoints}"
        log_debug ""
        log_debug "not connected endpoints: "
        log_debug "${not_conn_endpoints}"
#        log_debug ""
#        log_debug "diff: '${diff}' | warn: '${warn}' / crit: '${crit}'"
        log_debug ""
#      fi
  fi



  sleep 10m
done
