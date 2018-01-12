
# wait for mariadb / mysql
#
wait_for_database() {

  RETRY=15

  # wait for database
  #
  until [[ ${RETRY} -le 0 ]]
  do
    nc ${MYSQL_HOST} ${MYSQL_PORT} < /dev/null > /dev/null

    [[ $? -eq 0 ]] && break

    log_info "Waiting for database on host '${MYSQL_HOST}' to come up"

    sleep 13s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [[ ${RETRY} -le 0 ]]
  then
    log_error "Could not connect to database on ${MYSQL_HOST}:${MYSQL_PORT}"
    exit 1
  fi

  sleep 2s

  RETRY=10

  # must start initdb and do other jobs well
  #
  until [[ ${RETRY} -le 0 ]]
  do
    mysql ${MYSQL_OPTS} --execute="select 1 from mysql.user limit 1" > /dev/null

    [[ $? -eq 0 ]] && break

    log_info "wait for the database for her initdb and all other jobs"
    sleep 13s
    RETRY=$(expr ${RETRY} - 1)
  done

  sleep 2s
}

wait_for_database
