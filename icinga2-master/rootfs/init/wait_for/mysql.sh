
# wait for mariadb / mysql
#
wait_for_database() {

  RETRY=20

  set +e
  set +u

  until [[ ${RETRY} -le 0 ]]
  do
    host=$(dig +noadditional +noqr +noquestion +nocmd +noauthority +nostats +nocomments ${MYSQL_HOST} | wc -l)

    if [[ $host -eq 0 ]]
    then
      RETRY=$(expr ${RETRY} - 1)
      sleep 10s
    else
      break
    fi
  done

  # wait for database
  #
  until [[ ${RETRY} -le 0 ]]
  do
    # -v              Verbose
    # -w secs         Timeout for connects and final net reads
    # -X proto        Proxy protocol: "4", "5" (SOCKS) or "connect"
    #
    status=$(nc -v -w1 -X connect ${MYSQL_HOST} ${MYSQL_PORT} 2>&1)

    if [[ $(echo "${status}" | grep -c succeeded) -eq 1 ]]
    then
      break
    else
      sleep 10s
      RETRY=$(expr ${RETRY} - 1)
    fi
  done

  if [[ ${RETRY} -le 0 ]]
  then
    log_error "Could not connect to database on ${MYSQL_HOST}:${MYSQL_PORT}"
    exit 1
  fi

  sleep 2s

  RETRY=15

  # must start initdb and do other jobs well
  #
  until [[ ${RETRY} -le 0 ]]
  do
    mysql ${MYSQL_OPTS} --execute="select 1 from mysql.user limit 1" > /dev/null

    [[ $? -eq 0 ]] && break

    log_info "wait for the database for her initdb and all other jobs"
    sleep 10s
    RETRY=$(expr ${RETRY} - 1)
  done

  sleep 2s

  set -e
  set -u
}

wait_for_database
