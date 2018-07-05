
wait_for_port() {

  local server=${1}
  local port=${2}
  local retry=${3:-30}

  until [[ ${retry} -le 0 ]]
  do
    # -v              Verbose
    # -w secs         Timeout for connects and final net reads
    # -X proto        Proxy protocol: "4", "5" (SOCKS) or "connect"
    #
    status=$(nc -v -w1 -X connect ${server} ${port} 2>&1)

    if [[ $(echo "${status}" | grep -c succeeded) -eq 1 ]]
    then
      break
    else
      sleep 5s
      retry=$(expr ${retry} - 1)
    fi
  done

  if [[ ${retry} -le 0 ]]
  then
    log_error "could not connect to the icinga2 master instance '${server}'"
    exit 1
  fi
}

