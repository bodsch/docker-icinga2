
wait_for_dns() {

  local server=${1}
  local max_retry=${2:-9}
  local retry=0
  local host=

  log_info "check if a DNS record for '${server}' is available"

  until ( [[ ${retry} -eq ${max_retry} ]] || [[ ${retry} -gt ${max_retry} ]] )
  do
    # icinga2-master.matrix.lan has address 172.23.0.3
    # Host icinga2-master-fail not found: 3(NXDOMAIN)
    host=$(host ${server} 2> /dev/null)

    if [[ -z "${host}" ]] || [[ $(echo -e "${host}" | grep -c "has address") -eq 0 ]]
    then
      retry=$(expr ${retry} + 1)
      log_info "  wait for a valid dns record (${retry}/${max_retry})"
      sleep 10s
    else
      break
    fi
  done

  if [[ ${retry} -eq ${max_retry} ]] || [[ ${retry} -gt ${max_retry} ]]
  then
    log_error "a DNS record for '${server}' could not be determined."
    log_error "$(host ${server})"
    exit 1
  fi
}
