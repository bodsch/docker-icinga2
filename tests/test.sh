#!/bin/bash

ICINGA2_MASTER=${ICINGA2_MASTER:-"localhost"}
ICINGA2_API_PORT=${ICINGA2_API_PORT:-5665}
ICINGA2_API_USER="root"
ICINGA2_API_PASSWORD="icinga"

CERTIFICATE_SERVER=${CERTIFICATE_SERVER:-${ICINGA2_MASTER}}
CERTIFICATE_PORT=${CERTIFICATE_PORT:-8080}
CERTIFICATE_PATH=${CERTIFICATE_PATH:-/}

CURL=$(which curl 2> /dev/null)
NC=$(which nc 2> /dev/null)
NC_OPTS="-z"


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
    echo "api request are successfull"
    echo "${code}" | jq --raw-output ".results[].status.api.zones"
  else
    echo ${code}
    echo "api request failed"
  fi
}

inspect() {

  for d in database icingaweb2 icinga2-master icinga2-satellite-1
  do
    # docker inspect --format "{{lower .Name}}" ${d}
    docker inspect --format '{{with .State}} {{$.Name}} has pid {{.Pid}} {{end}}' ${d}
  done
}

echo "wait 5 minutes for start"
sleep 5m

inspect

wait_for_icinga_master
wait_for_icinga_cert_service
api_request

exit 0

