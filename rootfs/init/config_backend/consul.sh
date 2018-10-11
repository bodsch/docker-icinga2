#!/bin/sh

wait_for_config_backend() {

  [[ -z "${CONFIG_BACKEND_SERVER}" ]] || [[ -z "${CONFIG_BACKEND}"  ]] && return

  . /init/wait_for/dns.sh
  . /init/wait_for/port.sh

  wait_for_dns ${CONFIG_BACKEND_SERVER}
  wait_for_port ${CONFIG_BACKEND_SERVER} 8500 50

  sleep 5s
}

register_node()  {

  [[ -z "${CONFIG_BACKEND_SERVER}" ]] || [[ -z "${CONFIG_BACKEND}"  ]] && return

  _curl_data() {

    local short=$(hostname -s)

    cat << EOF
{
  "ID": "${HOSTNAME}",
  "Name": "${short}",
  "Port": 5665,
  "tags": ["icinga","${ICINGA2_TYPE}"]
}
EOF
  }

  data=$(curl \
    --silent \
    --request PUT \
    ${CONFIG_BACKEND_SERVER}:8500/v1/agent/service/register \
    --data "$(_curl_data)")
}

set_var() {

  [[ -z "${CONFIG_BACKEND_SERVER}" ]] || [[ -z "${CONFIG_BACKEND}"  ]] && return

  local consul_key=${1}
  local consul_var=${2}

  data=$(curl \
    --request PUT \
    --silent \
    ${CONFIG_BACKEND_SERVER}:8500/v1/kv/${HOSTNAME}/${consul_key} \
    --data ${consul_var})

#  curl \
#    --silent \
#    ${CONFIG_BACKEND_SERVER}:8500/v1/kv/${consul_key}
}

get_var() {

  [[ -z "${CONFIG_BACKEND_SERVER}" ]] || [[ -z "${CONFIG_BACKEND}"  ]] && return

  local consul_key=${1}

  data=$(curl \
    --silent \
    ${CONFIG_BACKEND_SERVER}:8500/v1/kv/${HOSTNAME}/${consul_key})

  if [[ ! -z "${data}" ]]
  then
    value=$(echo -e ${data} | jq --raw-output .[].Value 2> /dev/null)

    if [[ ! -z "${value}" ]]
    then
      echo ${value} | base64 -d
    else
      echo ""
      #echo "${decoded}"
    fi
  fi
}

wait_for_config_backend
register_node
