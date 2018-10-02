
wait_for_dns() {

  local server=${1}
  local max_retry=${2:-9}
  local retry=0
  local host=

  log_info "check if a DNS record for '${server}' is available"

  until [[ ${max_retry} -lt ${retry} ]]
  do
    host=$(dig +noadditional +noqr +noquestion +nocmd +noauthority +nostats +nocomments ${server})

#     log_debug "${retry} - '${host}'"

    if [[ -z "${host}" ]] || [[ $(echo -e "${host}" | wc -l) -eq 0 ]]
    then
      retry=$(expr ${retry} + 1)
      log_info "  wait for a valid dns record (${retry}/${max_retry})"
      sleep 10s
    else
      break
    fi
  done

#   echo "[[ ${retry} -lt ${max_retry} ]]"

  if [[ ${retry} -eq ${max_retry} ]] || [[ ${retry} -gt ${max_retry} ]]
  then
    log_error "a DNS record for '${server}' could not be determined."
    log_error "$(host ${server})"
    exit 1
  fi
}
