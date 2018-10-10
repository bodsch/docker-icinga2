
wait_for_config_backend() {

  [[ -z "${CONFIG_BACKEND_SERVER}" ]] || [[ -z "${CONFIG_BACKEND}"  ]] && return

  RETRY=50
  local http_response_code=0

  until [[ 200 -ne $http_response_code ]] && [[ ${RETRY} -le 0 ]]
  do
    http_response_code=$(curl \
      -w %{response_code} \
      --silent \
      --output /dev/null \
      http://${CONFIG_BACKEND_SERVER}:2379/health)

    [[ 200 -eq $http_response_code ]] && break

    sleep 5s

    RETRY=$(expr ${RETRY} - 1)
  done

  if [[ ${RETRY} -le 0 ]]
  then
    log_error "could not connect to the '${CONFIG_BACKEND}' instance '${CONFIG_BACKEND_SERVER}'"
    CONSUL=
    CONFIG_BACKEND=
  else
    create_directory_structure
  fi
}

create_directory_structure() {

  # second, create a directory for service related entries
  data=$(curl \
      --silent \
      --request PUT \
      http://${CONFIG_BACKEND_SERVER}:2379/v2/keys \
      --data 'dir=true')

  # as last, create a directory for ${HOSTNAME} related entries
  data=$(curl \
      --silent \
      --request PUT \
      http://${CONFIG_BACKEND_SERVER}:2379/v2/keys/${HOSTNAME} \
      --data 'dir=true')
}

register_node()  {

  local address=$(hostname -i)

  # in first, create a services directory for comming services
  #
  data=$(curl \
      --silent \
      --request PUT \
      http://${CONFIG_BACKEND_SERVER}:2379/v2/keys/services \
      --data 'dir=true')

  # register service
  data=$(curl \
      --silent \
      --request PUT \
      http://${CONFIG_BACKEND_SERVER}:2379/v2/keys/services/${HOSTNAME} \
      --data 'dir=true')

  # register service
  data=$(curl \
      --silent \
      --request PUT \
      http://${CONFIG_BACKEND_SERVER}:2379/v2/keys/services/${HOSTNAME}/fqdn \
      --data "value=$(hostname -f)")

  data=$(curl \
      --silent \
      --request PUT \
      http://${CONFIG_BACKEND_SERVER}:2379/v2/keys/services/${HOSTNAME}/name \
      --data "value=$(hostname -s)")

  data=$(curl \
      --silent \
      --request PUT \
      http://${CONFIG_BACKEND_SERVER}:2379/v2/keys/services/${HOSTNAME}/ip \
      --data "value=$(hostname -i)")
}

set_var() {

  local key=${1}
  local var=${2}

  data=$(curl \
    --request PUT \
    --silent \
    ${CONFIG_BACKEND_SERVER}:2379/v2/keys/${HOSTNAME}/${key} \
    --data "value=${var}")
}

get_var() {

  local key=${1}
  local result=
  local error_code=

  local data=$(curl \
    --silent \
    ${CONFIG_BACKEND_SERVER}:2379/v2/keys/${HOSTNAME}/${key})

  error_code=$(echo -e "${data}" | jq --raw-output .errorCode)

  if [[ ${error_code} = 'null' ]]
  then
    # {"action":"get","node":{"key":"/DBA/database/root_password","value":"...","modifiedIndex":7,"createdIndex":7}}
    value=$(echo -e "${data}" | jq --raw-output .node.value | sed 's|"||g')
    result=${value}
  elif [[ ! -z "${error_code}" ]]
  then
    # {"errorCode":100,"message":"Key not found","cause":"/DBA/database/database","index":5}
#    log_error "$(echo -e "${data}" | jq --raw-output .message)"
    result=
  else
    result=
  fi

  echo ${result}
}
