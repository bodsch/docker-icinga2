#!/bin/sh
#
#

if [ ${DEBUG} ]
then
  set -x
fi

WORK_DIR=${WORK_DIR:-/srv}
WORK_DIR=${WORK_DIR}/icinga2

initfile=${WORK_DIR}/run.init

MYSQL_HOST=${MYSQL_HOST:-""}
MYSQL_PORT=${MYSQL_PORT:-"3306"}

MYSQL_ROOT_USER=${MYSQL_ROOT_USER:-"root"}
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-""}
MYSQL_OPTS=

ICINGA_CLUSTER=${ICINGA_CLUSTER:-false}
ICINGA_MASTER=${ICINGA_MASTER:-""}

ICINGA_CERT_SERVICE_API_USER=${ICINGA_CERT_SERVICE_API_USER:-""}
ICINGA_CERT_SERVICE_API_PASSWORD=${ICINGA_CERT_SERVICE_API_PASSWORD:-""}

CARBON_HOST=${CARBON_HOST:-""}
CARBON_PORT=${CARBON_PORT:-2003}

IDO_DATABASE_NAME=${IDO_DATABASE_NAME:-"icinga2core"}
IDO_PASSWORD=${IDO_PASSWORD:-$(pwgen -s 15 1)}

USER=
GROUP=

HOSTNAME=$(hostname -s)

if [ -z ${MYSQL_HOST} ]
then
  echo " [i] no MYSQL_HOST set ..."
else
  MYSQL_OPTS="--host=${MYSQL_HOST} --user=${MYSQL_ROOT_USER} --password=${MYSQL_ROOT_PASS} --port=${MYSQL_PORT}"
fi

# -------------------------------------------------------------------------------------------------

waitForDatabase() {

  if [ -z "${MYSQL_OPTS}" ]
  then
    return
  fi

  # wait for needed database
  while ! nc -z ${MYSQL_HOST} ${MYSQL_PORT}
  do
    sleep 3s
  done

  # must start initdb and do other jobs well
  echo " [i] wait for the database for her initdb and all other jobs"

  until mysql ${MYSQL_OPTS} --execute="select 1 from mysql.user limit 1" > /dev/null
  do
    echo " . "
    sleep 3s
  done
}

waitForIcingaMaster() {

  if [ ${ICINGA_CLUSTER} == false ]
  then
    return
  fi

  # wait for needed database
  while ! nc -z ${ICINGA_MASTER} 5665
  do
    sleep 3s
  done

  echo " [i] wait for icinga2 Core"
  sleep 10s
}



prepare() {

  for u in nagios icinga
  do
    if [ "$(getent passwd ${u})" ]
    then
      USER="${u}"
      break
    fi
  done

  for g in nagios icinga
  do
    if [ "$(getent group ${g})" ]
    then
      GROUP="${g}"
      break
    fi
  done

  if [ -f /etc/icinga2/icinga2.sysconfig ]
  then
    . /etc/icinga2/icinga2.sysconfig

  #  ICINGA2_RUNasUSER=${ICINGA2_USER}
  #  ICINGA2_RUNasGROUP=${ICINGA2_GROUP}
  else
    ICINGA2_RUN_DIR=$(/usr/sbin/icinga2 variable get RunDir)
  #  ICINGA2_RUNasUSER=$(/usr/sbin/icinga2 variable get RunAsUser)
  #  ICINGA2_RUNasGROUP=$(/usr/sbin/icinga2 variable get RunAsGroup)
  fi

  [ -d ${WORK_DIR} ] || mkdir -p ${WORK_DIR}
}


correctRights() {

  chmod 1777 /tmp

  if ( [ -z ${USER} ] || [ -z ${GROUP} ] )
  then
    echo " [E] No User/Group nagios or icinga found!"
  else

    [ -d /var/lib/icinga2/api/log/current ] || mkdir -p /var/lib/icinga2/api/log/current

    chown -R ${USER}:root     /etc/icinga2
    chown -R ${USER}:${GROUP} /var/lib/icinga2
    chown -R ${USER}:${GROUP} ${ICINGA2_RUN_DIR}/icinga2
  fi
}


configureIcinga2() {

  # remove var.os to disable ssh-checks
  if [ -f /etc/icinga2/conf.d/hosts.conf ]
  then
    sed -i -e "s,^.*\ vars.os\ \=\ .*,  //\ vars.os = \"Linux\",g" /etc/icinga2/conf.d/hosts.conf
  fi

}


configureGraphite() {

  if ( [ ! -z ${CARBON_HOST} ] && [ ! -z ${CARBON_PORT} ] )
  then
    icinga2 feature enable graphite

    if [ -e /etc/icinga2/features-enabled/graphite.conf ]
    then
      sed -i "s,^.*\ //host\ =\ .*,  host\ =\ \"${CARBON_HOST}\",g" /etc/icinga2/features-enabled/graphite.conf
      sed -i "s,^.*\ //port\ =\ .*,  port\ =\ \"${CARBON_PORT}\",g" /etc/icinga2/features-enabled/graphite.conf
    fi
  else
    echo " [i] no Settings for Graphite Feature found"
  fi

}


configurePKI() {

  if [ -f '/usr/local/sbin/icinga2_pki.sh' ]
  then

    . /usr/local/sbin/icinga2_pki.sh

  fi

}


configureDatabase() {

  if [ -z "${MYSQL_OPTS}" ]
  then
    return
  fi

  /usr/sbin/icinga2 feature enable ido-mysql

  local logfile="${WORK_DIR}/icinga2-ido-mysql-schema.log"
  local status="${WORK_DIR}/mysql-schema.import"

  if [ ! -f ${status} ]
  then
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

    mysql ${MYSQL_OPTS} --force ${IDO_DATABASE_NAME}  < /usr/share/icinga2-ido-mysql/schema/mysql.sql  >> ${logfile} 2>&1

    if [ $? -eq 0 ]
    then
      touch ${status}
    else
      echo " [E] can't insert the icinga2 Database Schema"
      exit 1
    fi
  else
    # check database version
    # and install the update, when it needed
    lastest_update=$(ls -1 /usr/share/icinga2-ido-mysql/schema/upgrade/*sql  | sort | tail -n1)
    new_version=$(grep icinga_dbversion ${lastest_update} | grep idoutils | cut -d ',' -f 5 | sed -e "s| ||g" -e "s|\\'||g")

    query="select name, version from icinga_dbversion"

    mysql ${MYSQL_OPTS} --force ${IDO_DATABASE_NAME} --batch --execute="${query}" | \
    tail -n +2 | \
    tr '\t' '|' | \
    while IFS='|' read NAME VERSION junk
    do
      if [ "${new_version}" != "${VERSION}" ]
      then
        mysql ${MYSQL_OPTS} --force ${IDO_DATABASE_NAME}  < ${lastest_update}  >> ${logfile} 2>&1
      fi
    done

  fi

  sed -i \
    -e 's|//host \= \".*\"|host \=\ \"'${MYSQL_HOST}'\"|g' \
    -e 's|//password \= \".*\"|password \= \"'${IDO_PASSWORD}'\"|g' \
    -e 's|//user =\ \".*\"|user =\ \"icinga2\"|g' \
    -e 's|//database =\ \".*\"|database =\ \"'${IDO_DATABASE_NAME}'\"|g' \
    /etc/icinga2/features-available/ido-mysql.conf

}


configureAPIUser() {

  local api_file="/etc/icinga2/conf.d/api-users.conf"

  cat << EOF > ${api_file}

object ApiUser "root" {
  password    = "icinga"
  client_cn   = NodeName
  permissions = [ "*" ]
}

EOF

  if ( [ ! -z ${DASHING_API_USER} ] && [ ! -z ${DASHING_API_PASS} ] )
  then
    echo " [i] enable API User '${DASHING_API_USER}'"

    if [ $(grep -c "object ApiUser \"${DASHING_API_USER}\"" ${api_file}) -eq 0 ]
    then

      cat << EOF >> ${api_file}

object ApiUser "${DASHING_API_USER}" {
  password    = "${DASHING_API_PASS}"
  client_cn   = NodeName
  permissions = [ "*" ]
}

EOF
    fi
  fi

  if ( [ ! -z ${ICINGA_CERT_SERVICE_API_USER} ] && [ ! -z ${ICINGA_CERT_SERVICE_API_PASSWORD} ] )
  then
    echo " [i] enable API User '${ICINGA_CERT_SERVICE_API_USER}'"

    if [ $(grep -c "object ApiUser \"${ICINGA_CERT_SERVICE_API_USER}\"" ${api_file}) -eq 0 ]
    then

      cat << EOF >> ${api_file}

object ApiUser "${ICINGA_CERT_SERVICE_API_USER}" {
  password    = "${ICINGA_CERT_SERVICE_API_PASSWORD}"
  client_cn   = NodeName
  permissions = [ "*" ]
}

EOF
    fi
  fi

}


startSupervisor() {

  echo -e "\n Starting Supervisor.\n\n"

  if [ -f /etc/supervisord.conf ]
  then
    /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
  else
    exec /bin/sh
  fi
}


run() {

  if [ ! -f "${initfile}" ]
  then
    waitForDatabase
    prepare
    configureGraphite
    configureDatabase
    configureAPIUser

    configurePKI

    correctRights

    if [ ! -z "${MYSQL_OPTS}" ]
    then
      echo -e "\n"
      echo " ==================================================================="
      echo " MySQL user 'icinga2' password set to '${IDO_PASSWORD}'"
      echo "   and use database '${IDO_DATABASE_NAME}'"
      echo " ==================================================================="
      echo ""
    fi
  fi

  startSupervisor
}


run

# EOF
