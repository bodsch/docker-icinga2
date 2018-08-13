
wait_for_dns() {

  local server=${1}
  local retry=${2:-30}

  until [[ ${retry} -le 0 ]]
  do
    host=$(dig +noadditional +noqr +noquestion +nocmd +noauthority +nostats +nocomments ${server} | wc -l)

    if [[ $host -eq 0 ]]
    then
      retry=$(expr ${retry} - 1)
      sleep 10s
    else
      break
    fi
  done

  if [[ ${retry} -le 0 ]]
  then
    log_error "could not found dns entry for instance '${server}'"
    exit 1
  fi
}
