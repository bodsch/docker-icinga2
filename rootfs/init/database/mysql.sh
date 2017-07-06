
if [ -z ${MYSQL_HOST} ]
then
  echo " [i] no MYSQL_HOST set ..."

  return
else
  MYSQL_OPTS="--host=${MYSQL_HOST} --user=${MYSQL_ROOT_USER} --password=${MYSQL_ROOT_PASS} --port=${MYSQL_PORT}"
fi

# Version compare function
# 'stolen' from https://github.com/psi-4ward/docker-icinga2/blob/master/rootfs/init/mysql_setup.sh
# but modifyed for /bin/sh support
version_compare () {

  if [[ ${1} == ${2} ]]
  then
    echo '='
    return 0
  fi

  left="$(echo ${1} | sed 's/\.//g')"
  right="$(echo ${2} | sed 's/\.//g')"

  if [ ${left} -gt ${right} ]
  then
    echo ">"
    return 0
  elif [ ${left} -lt ${right} ]
  then
    echo "<"
    return 0
  else
    echo "="
    return 0
  fi

}


waitForDatabase() {

  RETRY=15

  # wait for database
  #
  until [ ${RETRY} -le 0 ]
  do
    nc ${MYSQL_HOST} ${MYSQL_PORT} < /dev/null > /dev/null

    [ $? -eq 0 ] && break

    echo " [i] Waiting for database to come up"

    sleep 5s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [ $RETRY -le 0 ]
  then
    echo " [E] Could not connect to Database on ${MYSQL_HOST}:${MYSQL_PORT}"
    exit 1
  fi

  RETRY=10

  # must start initdb and do other jobs well
  #
  until [ ${RETRY} -le 0 ]
  do
    mysql ${MYSQL_OPTS} --execute="select 1 from mysql.user limit 1" > /dev/null

    [ $? -eq 0 ] && break

    echo " [i] wait for the database for her initdb and all other jobs"
    sleep 5s
    RETRY=$(expr ${RETRY} - 1)
  done

}


createSchema() {

  enableIcingaFeature ido-mysql

  # check if database already created ...
  #
  query="SELECT TABLE_SCHEMA FROM information_schema.tables WHERE table_schema = \"${IDO_DATABASE_NAME}\" limit 1;"

  status=$(mysql ${MYSQL_OPTS} --batch --execute="${query}")

  if [ $(echo "${status}" | wc -w) -eq 0 ]
  then
    # Database isn't created
    # well, i do my job ...
    #
    echo " [i] Initializing databases and icinga2 configurations."

    (
      echo "--- create user '${IDO_DATABASE_NAME}'@'%' IDENTIFIED BY '${IDO_PASSWORD}';"
      echo "CREATE DATABASE IF NOT EXISTS ${IDO_DATABASE_NAME};"
      echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON ${IDO_DATABASE_NAME}.* TO 'icinga2'@'%' IDENTIFIED BY '${IDO_PASSWORD}';"
      echo "FLUSH PRIVILEGES;"
    ) | mysql ${MYSQL_OPTS}

    if [ $? -eq 1 ]
    then
      echo " [E] can't create Database '${IDO_DATABASE_NAME}'"
      exit 1
    fi

    insertSchema
  fi
}

insertSchema() {

    # create the ido schema
    #
    mysql ${MYSQL_OPTS} --force ${IDO_DATABASE_NAME}  < /usr/share/icinga2-ido-mysql/schema/mysql.sql

    if [ $? -gt 0 ]
    then
      echo " [E] can't insert the icinga2 Database Schema"
      exit 1
    fi

}

updateSchema() {

    # Database already created
    #
    # check database version
    # and install the update, when it needed
    #
    query="select version from ${IDO_DATABASE_NAME}.icinga_dbversion"
    db_version=$(mysql ${MYSQL_OPTS} --batch --execute="${query}" | tail -n1)

    echo " [i] Database Version: ${db_version}"

    if [ -z "${db_version}" ]
    then
      echo " [w] no database version found. skip database upgrade"

      insertSchema
      updateSchema
    else

      for DB_UPDATE_FILE in $(ls -1 /usr/share/icinga2-ido-mysql/schema/upgrade/*.sql)
      do
        FILE_VER=$(grep icinga_dbversion ${DB_UPDATE_FILE} | grep idoutils | cut -d ',' -f 5 | sed -e "s| ||g" -e "s|\\'||g")

        if [ "$(version_compare ${db_version} ${FILE_VER})" = "<" ]
        then
          echo " [i] apply Database Update '${FILE_VER}' from '${DB_UPDATE_FILE}'"

          mysql ${MYSQL_OPTS} --force ${IDO_DATABASE_NAME}  < /usr/share/icinga2-ido-mysql/schema/upgrade/${DB_UPDATE_FILE} || exit $?
        fi
      done

    fi
}

createConfig() {

  # create the IDO configuration
  #
  sed -i \
    -e 's|//host \= \".*\"|host \=\ \"'${MYSQL_HOST}'\"|g' \
    -e 's|//port \= \".*\"|port \=\ \"'${MYSQL_PORT}'\"|g' \
    -e 's|//password \= \".*\"|password \= \"'${IDO_PASSWORD}'\"|g' \
    -e 's|//user =\ \".*\"|user =\ \"icinga2\"|g' \
    -e 's|//database =\ \".*\"|database =\ \"'${IDO_DATABASE_NAME}'\"|g' \
    /etc/icinga2/features-available/ido-mysql.conf

}


waitForDatabase

createSchema
updateSchema
createConfig

# EOF
