
[[ -z ${MYSQL_HOST} ]] && return

MYSQL_OPTS="--host=${MYSQL_HOST} --user=${MYSQL_ROOT_USER} --password=${MYSQL_ROOT_PASS} --port=${MYSQL_PORT}"


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

  if [[ ${left} -gt ${right} ]]
  then
    echo ">"
    return 0
  elif [[ ${left} -lt ${right} ]]
  then
    echo "<"
    return 0
  else
    echo "="
    return 0
  fi
}

# create IDO database schema
#
create_schema() {

  enable_icinga_feature ido-mysql

  # check if database already created ...
  #
  query="SELECT TABLE_SCHEMA FROM information_schema.tables WHERE table_schema = \"${IDO_DATABASE_NAME}\" limit 1;"

  status=$(mysql ${MYSQL_OPTS} --batch --execute="${query}")

  if [[ $(echo "${status}" | wc -w) -eq 0 ]]
  then
    # Database isn't created
    # well, i do my job ...
    #
    log_info "create IDO database '${IDO_DATABASE_NAME}'"

    (
      echo "--- create user '${IDO_DATABASE_NAME}'@'%' IDENTIFIED BY '${IDO_PASSWORD}';"
      echo "CREATE DATABASE IF NOT EXISTS ${IDO_DATABASE_NAME};"
      echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON ${IDO_DATABASE_NAME}.* TO 'icinga2'@'%' IDENTIFIED BY '${IDO_PASSWORD}';"
      echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON ${IDO_DATABASE_NAME}.* TO 'icinga2'@'$(hostname -i)' IDENTIFIED BY '${IDO_PASSWORD}';"
      echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON ${IDO_DATABASE_NAME}.* TO 'icinga2'@'$(hostname -s)' IDENTIFIED BY '${IDO_PASSWORD}';"
      echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON ${IDO_DATABASE_NAME}.* TO 'icinga2'@'$(hostname -f)' IDENTIFIED BY '${IDO_PASSWORD}';"
      echo "FLUSH PRIVILEGES;"
    ) | mysql ${MYSQL_OPTS}

    if [[ $? -eq 1 ]]
    then
      log_error "can't create database '${IDO_DATABASE_NAME}'"
      exit 1
    fi

    insert_schema
  fi
}

# insert database structure
#
insert_schema() {

  log_info "import IDO database schema"

  # create the ido schema
  #
  mysql ${MYSQL_OPTS} --force ${IDO_DATABASE_NAME}  < /usr/share/icinga2-ido-mysql/schema/mysql.sql

  if [[ $? -gt 0 ]]
  then
    log_error "can't insert the IDO database schema"
    exit 1
  fi
}

# update database schema
#
update_schema() {

  # Database already created
  #
  # check database version
  # and install the update, when it needed
  #
  query="select version from ${IDO_DATABASE_NAME}.icinga_dbversion"
  db_version=$(mysql ${MYSQL_OPTS} --batch --execute="${query}" | tail -n1)

  if [[ -z "${db_version}" ]]
  then
    log_warn "no database version found. skip database upgrade."

    insert_schema
    update_schema
  else

    upgrape_directory="/usr/share/icinga2-ido-mysql/schema/upgrade"

    log_info "IDO database version: ${db_version}"

    for DB_UPDATE_FILE in $(ls -1 ${upgrape_directory}/*.sql)
    do
      FILE_VER=$(grep icinga_dbversion ${DB_UPDATE_FILE} | grep idoutils | cut -d ',' -f 5 | sed -e "s| ||g" -e "s|'||g")

      if [[ "$(version_compare ${db_version} ${FILE_VER})" = "<" ]]
      then
        log_info "apply database update '${FILE_VER}' from '${DB_UPDATE_FILE}'"

        mysql ${MYSQL_OPTS} --force ${IDO_DATABASE_NAME}  < ${DB_UPDATE_FILE}

        if [[ $? -gt 0 ]]
        then
          log_error "database update ${DB_UPDATE_FILE} failed"
          exit 1
        fi
      fi
    done
  fi
}

# update database configuration
#
create_config() {

  log_info "create IDO configuration"

  # create the IDO configuration
  #

  cat << EOF > /etc/icinga2/features-available/ido-mysql.conf

library "db_ido_mysql"

object IdoMysqlConnection "ido-mysql" {
  user     = "icinga2"
  password = "${IDO_PASSWORD}"
  host     = "${MYSQL_HOST}"
  database = "${IDO_DATABASE_NAME}"
  port     = "${MYSQL_PORT}"
}
EOF

#  sed -i \
#    -e 's|host \= \".*\"|host \=\ \"'${MYSQL_HOST}'\"|g' \
#    -e 's|port \= \".*\"|port \=\ \"'${MYSQL_PORT}'\"|g' \
#    -e 's|password \= \".*\"|password \= \"'${IDO_PASSWORD}'\"|g' \
#    -e 's|user =\ \".*\"|user =\ \"icinga2\"|g' \
#    -e 's|database =\ \".*\"|database =\ \"'${IDO_DATABASE_NAME}'\"|g' \
#    /etc/icinga2/features-available/ido-mysql.conf
}

. /init/wait_for/mysql.sh

create_schema
update_schema
create_config

# EOF
