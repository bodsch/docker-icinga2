#!/bin/bash

ICINGA2_MASTER=${ICINGA2_MASTER:-"localhost"}
ICINGA2_API_PORT=${ICINGA2_API_PORT:-5665}
ICINGA2_API_USER="root"
ICINGA2_API_PASSWORD="icinga"

ICINGA2_UPTIME=125

CERTIFICATE_SERVER=${CERTIFICATE_SERVER:-${ICINGA2_MASTER}}
CERTIFICATE_PORT=${CERTIFICATE_PORT:-443}
CERTIFICATE_PATH=${CERTIFICATE_PATH:-/cert-service/}

[[ ${CERTIFICATE_PORT} = *443 ]] && protocol=https || protocol=http
export CERT_SERVICE_PROTOCOL=${protocol}

CURL=$(which curl 2> /dev/null)

# wait for the Icinga2 Instances Master or Satellite
#
wait_for_icinga_instances() {

  echo "wait for the icinga2 instances"

  for s in $(docker-compose ps | grep icinga2 | awk  '{print($1)}')
  do
    instance_uptime=

    if [ $(echo "${s}" | egrep -ce satellite) -eq 1 ]
    then
      # satellite
      instance_uptime=30
      echo "an satellite instance should run ${instance_uptime} seconds without interruption"
    else
      # master
      instance_uptime=100
      echo "the master instance must run ${instance_uptime} seconds without interruption"
    fi

    backend_network=$(docker network ls | egrep "*icinga2_backend*" | awk '{print $2}')

    ip=$(docker network inspect ${backend_network} | jq -r ".[].Containers | to_entries[] | select(.value.Name==\"${s}\").value.IPv4Address" | awk -F "/" '{print $1}')

    RETRY=35

    until [[ ${RETRY} -le 0 ]]
    do

      echo "  ${s} | ${RETRY}"

      code=$(curl \
        --user ${ICINGA2_API_USER}:${ICINGA2_API_PASSWORD} \
        --silent \
        --insecure \
        --header 'Accept: application/json' \
        https://${ip}:${ICINGA2_API_PORT}/v1/status/CIB)

      if [[ ! -z "${code}" ]]
      then
        uptime=$(echo "${code}" | jq --raw-output '.results[].status.uptime' 2> /dev/null)

        utime=${uptime%.*}

        echo "    - ${utime} / ${instance_uptime}"

        if [[ ${utime} -gt ${instance_uptime} ]]
        then
          echo  "the icinga2 instance ${s} is ${utime} seconds up and alive"
          break
        else
          sleep 10s
          RETRY=$(expr ${RETRY} - 1)
        fi
      else
        sleep 10s
        RETRY=$(expr ${RETRY} - 1)
      fi
    done

  done
}


# wait for the Certificate Service
#
wait_for_icinga_cert_service() {

  echo -e "\nwait for the certificate service"

  RETRY=35
  # wait for the running certificate service
  #
  until [[ ${RETRY} -le 0 ]]
  do
    timeout 1 bash -c "cat < /dev/null > /dev/tcp/${CERTIFICATE_SERVER}/${CERTIFICATE_PORT}" 2> /dev/null
    if [ $? -eq 0 ]
    then
      break
    else
      sleep 10s
      RETRY=$(expr ${RETRY} - 1)
    fi
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
      --location \
      --insecure \
      --request GET \
      --write-out "%{http_code}\n" \
      --request GET \
      ${CERT_SERVICE_PROTOCOL}://${CERTIFICATE_SERVER}:${CERTIFICATE_PORT}${CERTIFICATE_PATH}/v2/health-check)

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

  echo ""
  code=$(curl \
    --user ${ICINGA2_API_USER}:${ICINGA2_API_PASSWORD} \
    --silent \
    --insecure \
    --header 'Accept: application/json' \
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

  echo ""
  for s in $(docker-compose ps | grep icinga2 | awk  '{print($1)}')
  do
    backend_network=$(docker network ls | egrep "*icinga2_backend*" | awk '{print $2}')

    ip=$(docker network inspect ${backend_network} | jq -r ".[].Containers | to_entries[] | select(.value.Name==\"${s}\").value.IPv4Address" | awk -F "/" '{print $1}')

    code=$(curl \
      --user ${ICINGA2_API_USER}:${ICINGA2_API_PASSWORD} \
      --silent \
      --insecure \
      --header 'Accept: application/json' \
      https://${ip}:5665/v1/status/IcingaApplication)

    #echo "'${s}' : '${code}'"

    if [[ ! -z "${code}" ]]
    then
      version=$(echo "${code}" | jq --raw-output '.results[].status.icingaapplication.app.version' 2> /dev/null)
      node_name=$(echo "${code}" | jq --raw-output '.results[].status.icingaapplication.app.node_name' 2> /dev/null)

      printf "service %-20s (fqdn: %-30s / ip: %s) | version: %s\n" "${s}" "${node_name}" "${ip}" "${version}"
    else
      echo "WARNING: '${s}' returned no application status"

      docker logs ${s}
    fi
  done
}


inspect() {

  echo ""
  echo "inspect needed containers"
  for d in $(docker ps | tail -n +2 | awk  '{print($1)}')
  do
    # docker inspect --format "{{lower .Name}}" ${d}
    c=$(docker inspect --format '{{with .State}} {{$.Name}} has pid {{.Pid}} {{end}}' ${d})
    s=$(docker inspect --format '{{json .State.Health }}' ${d} | jq --raw-output .Status)

    printf "%-40s - %s\n"  "${c}" "${s}"
  done
}


if [[ $(docker ps | tail -n +2  | wc -l) -eq 6 ]]
then
  inspect
  wait_for_icinga_cert_service
  wait_for_icinga_instances

  get_versions
  api_request

  exit 0
else
  echo "the test setup needs 5 containers"
  echo "only $(docker ps | tail -n +2  | wc -l) running"
  echo "please run "
  echo " make compose-file"
  echo " docker-compose up -d"
  echo "before"
  echo "or check your system"

  exit 1
fi
