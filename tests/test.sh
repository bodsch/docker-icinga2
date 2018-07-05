#!/bin/bash

ICINGA2_MASTER=${ICINGA2_MASTER:-"localhost"}
ICINGA2_API_PORT=${ICINGA2_API_PORT:-5665}
ICINGA2_API_USER="root"
ICINGA2_API_PASSWORD="icinga"

CERTIFICATE_SERVER=${CERTIFICATE_SERVER:-${ICINGA2_MASTER}}
CERTIFICATE_PORT=${CERTIFICATE_PORT:-8080}
CERTIFICATE_PATH=${CERTIFICATE_PATH:-/}

CURL=$(which curl 2> /dev/null)
NC=$(which ncat 2> /dev/null)
NC_OPTS="-z"

if [[ -z "${NC}" ]]
then
  NC=$(which nc 2> /dev/null)
  NC_OPTS=
fi


# wait for the Icinga2 Master
#
wait_for_icinga_master() {

  echo "wait for the icinga2 master"
  RETRY=35
  until [[ ${RETRY} -le 0 ]]
  do
    ${NC} ${NC_OPTS} ${ICINGA2_MASTER} 5665 < /dev/null > /dev/null

    [[ $? -eq 0 ]] && break

    sleep 5s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [[ $RETRY -le 0 ]]
  then
    echo "could not connect to the icinga2 master instance '${ICINGA2_MASTER}'"
    exit 1
  fi

  sleep 5s
}


# wait for the Certificate Service
#
wait_for_icinga_cert_service() {

  echo "wait for the certificate service"

  RETRY=35
  # wait for the running certificate service
  #
  until [[ ${RETRY} -le 0 ]]
  do
    ${NC} ${NC_OPTS} ${CERTIFICATE_SERVER} ${CERTIFICATE_PORT} < /dev/null > /dev/null

    [[ $? -eq 0 ]] && break

    sleep 5s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [[ $RETRY -le 0 ]]
  then
    echo "Could not connect to the certificate service '${CERTIFICATE_SERVER}'"
    exit 1
  fi

  # okay, the web service is available
  # but, we have a problem, when he runs behind a proxy ...
  # eg.: https://monitoring-proxy.tld/cert-cert-service
  #

  RETRY=30
  # wait for the certificate service health check behind a proxy
  #
  until [[ ${RETRY} -le 0 ]]
  do

    health=$(${CURL} \
      --silent \
      --request GET \
      --write-out "%{http_code}\n" \
      --request GET \
      http://${CERTIFICATE_SERVER}:${CERTIFICATE_PORT}${CERTIFICATE_PATH}/v2/health-check)

    if ( [[ $? -eq 0 ]] && [[ "${health}" == "healthy200" ]] )
    then
      break
    fi

    echo "Wait for the health check for the certificate service on '${CERTIFICATE_SERVER}'"
    sleep 5s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [[ $RETRY -le 0 ]]
  then
    echo "Could not a health check from the certificate service '${CERTIFICATE_SERVER}'"
    exit 1
  fi

  sleep 2s
}

api_request() {

  code=$(curl \
    --silent \
    --user ${ICINGA2_API_USER}:${ICINGA2_API_PASSWORD} \
    --header 'Accept: application/json' \
    --insecure \
    https://${ICINGA2_MASTER}:${ICINGA2_API_PORT}/v1/status/ApiListener)

  if [[ $? -eq 0 ]]
  then

    num_endpoints=$(echo "${code}" | jq --raw-output ".results[].status.api.num_endpoints")
    num_conn_endpoints=$(echo "${code}" | jq --raw-output ".results[].status.api.num_conn_endpoints")
    num_not_conn_endpoints=$(echo "${code}" | jq --raw-output ".results[].status.api.num_not_conn_endpoints")

    echo "api request are successfull"
    echo "endpoints summary:"
    echo "totaly: '${num_endpoints}' / connected: '${num_conn_endpoints}' / not connected: '${num_not_conn_endpoints}'"
    echo ""
    echo "connected endpoints: "
    echo "${code}" | jq --raw-output ".results[].status.api.conn_endpoints"
    echo ""
    echo "not connected endpoints: "
    echo "${code}" | jq --raw-output ".results[].status.api.not_conn_endpoints"
    echo ""
    echo "API zones:"
    echo "${code}" | jq --raw-output ".results[].status.api.zones"
    echo ""
  else
    echo ${code}
    echo "api request failed"
  fi
}


get_versions() {

  for s in icinga2-master icinga2-satellite-1
  do
    ip=$(docker network inspect dockericinga2_backend | jq -r ".[].Containers | to_entries[] | select(.value.Name==\"${s}\").value.IPv4Address" | awk -F "/" '{print $1}')

    code=$(curl \
      --user ${ICINGA2_API_USER}:${ICINGA2_API_PASSWORD} \
      --silent \
      --location \
      --header 'Accept: application/json' \
      --request GET \
      --insecure \
      https://${ip}:5665/v1/status/IcingaApplication)

#     echo "'${s}' : '${code}'"

    if [[ ! -z "${code}" ]]
    then
      version=$(echo "${code}" | jq --raw-output '.results[].status.icingaapplication.app.version' 2> /dev/null)
      node_name=$(echo "${code}" | jq --raw-output '.results[].status.icingaapplication.app.node_name' 2> /dev/null)

      echo "service ${s} (${node_name} ${ip}) has version: ${version}"
    else
      echo "WARNING: '${s}' returned no application status"

      docker logs ${s}
    fi
  done
}


inspect() {

  echo "inspect needed containers"
  for d in database icingaweb2 icinga2-master icinga2-satellite-1
  do
    # docker inspect --format "{{lower .Name}}" ${d}
    docker inspect --format '{{with .State}} {{$.Name}} has pid {{.Pid}} {{end}}' ${d}
  done
}

inspect
wait_for_icinga_master
wait_for_icinga_cert_service
get_versions
api_request

exit 0

