
# wait for the Icinga2 Master
#
wait_for_icinga_master() {

  # I can't wait for myself.
  #
  [[ "${ICINGA2_TYPE}" = "Master" ]] && return

  set +e
  set +u
  # log_info "Waiting for icinga2 master on host '${ICINGA2_MASTER}' to come up"

  RETRY=50

  until [[ ${RETRY} -le 0 ]]
  do
    host=$(dig +noadditional +noqr +noquestion +nocmd +noauthority +nostats +nocomments ${ICINGA2_MASTER} | wc -l)

    if [[ $host -eq 0 ]]
    then
      RETRY=$(expr ${RETRY} - 1)
      sleep 10s
    else
      break
    fi
  done

  until [[ ${RETRY} -le 0 ]]
  do
    # -v              Verbose
    # -w secs         Timeout for connects and final net reads
    # -X proto        Proxy protocol: "4", "5" (SOCKS) or "connect"
    #
    status=$(nc -v -w1 -X connect ${ICINGA2_MASTER} 5665 2>&1)

    if [[ $(echo "${status}" | grep -c succeeded) -eq 1 ]]
    then
      break
    else
      sleep 5s
      RETRY=$(expr ${RETRY} - 1)
    fi
  done

  if [[ ${RETRY} -le 0 ]]
  then
    log_error "could not connect to the icinga2 master instance '${ICINGA2_MASTER}'"
    exit 1
  fi

  sleep 5s

  set -e
  set -u
}

wait_for_icinga_master
