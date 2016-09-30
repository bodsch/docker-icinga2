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
ICINGA_SATELLITES=${ICINGA_SATELLITES:-""}

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
  echo " [i] wait for database for there initdb and do other jobs well"

  until mysql ${mysql_opts} --execute="select 1 from mysql.user limit 1" > /dev/null
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

  # must start initdb and do other jobs well
  echo " [i] wait for icinga2 Core"
  sleep 20s
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

  if [ ${ICINGA_MASTER} == ${HOSTNAME} ]
  then

    # icinga2 API cert - regenerate new private key and certificate when running in a new container
    if [ -f ${WORK_DIR}/pki/${HOSTNAME}.key ]
    then
      echo " [i] restore older PKI settings for host '${HOSTNAME}'"
      cp -ar ${WORK_DIR}/pki/${HOSTNAME}* /etc/icinga2/pki/
      cp -a ${WORK_DIR}/pki/ca.crt /etc/icinga2/pki/

      if [ $(icinga2 feature list | grep Enabled | grep api | wc -l) -eq 0 ]
      then
        icinga2 feature enable api
      fi
    fi

    sed -i "s,^.*\ NodeName\ \=\ .*,const\ NodeName\ \=\ \"${HOSTNAME}\",g" /etc/icinga2/constants.conf

    # icinga2 API cert - regenerate new private key and certificate when running in a new container
    if [ ! -f /etc/icinga2/pki/${HOSTNAME}.key ]
    then

      [ -d ${WORK_DIR}/pki ] || mkdir ${WORK_DIR}/pki

      PKI_CMD="icinga2 pki"

      PKI_KEY="/etc/icinga2/pki/${HOSTNAME}.key"
      PKI_CSR="/etc/icinga2/pki/${HOSTNAME}.csr"
      PKI_CRT="/etc/icinga2/pki/${HOSTNAME}.crt"

      icinga2 api setup

      ${PKI_CMD} new-cert --cn ${HOSTNAME} --key ${PKI_KEY} --csr ${PKI_CSR}
      ${PKI_CMD} sign-csr --csr ${PKI_CSR} --cert ${PKI_CRT}

      correctRights

      /usr/sbin/icinga2 daemon -c /etc/icinga2/icinga2.conf -e /var/log/icinga2/error.log &

      sleep 5s

      if [ ! -z "${ICINGA_SATELLITES}" ]
      then

        SATELLITES="$(echo ${ICINGA_SATELLITES} | sed 's|,| |g')"

        for s in ${SATELLITES}
        do
          dir="/tmp/${s}"
          salt=$(echo ${s} | sha256sum | cut -f 1 -d ' ')

          mkdir ${dir}
          chown icinga: ${dir}

          ${PKI_CMD} new-cert --cn ${s} --key ${dir}/${s}.key --csr ${dir}/${s}.csr
          ${PKI_CMD} sign-csr --csr ${dir}/${s}.csr --cert ${dir}/${s}.crt
          ${PKI_CMD} save-cert --key ${dir}/${s}.key --cert ${dir}/${s}.crt --trustedcert ${dir}/trusted-master.crt --host ${ICINGA_MASTER}
          # Receive Ticket from master...
          pki_ticket=$(${PKI_CMD} ticket --cn ${HOSTNAME} --salt ${salt})
          ${PKI_CMD} request --host ${ICINGA_MASTER} --port 5665 --ticket ${pki_ticket} --key ${dir}/${s}.key --cert ${dir}/${s}.crt --trustedcert ${dir}/trusted-master.crt --ca /etc/icinga2/pki/ca.crt

          cp -arv /tmp/${s} ${WORK_DIR}/pki/
        done

      fi

      killall icinga2
      sleep 20s
    fi

    cp -ar /etc/icinga2/pki ${WORK_DIR}/

    echo " [i] Finished cert generation"

  else

    waitForIcingaMaster

    icinga2 feature disable notification
    icinga2 feature enable api

    cp -av ${WORK_DIR}/pki/${HOSTNAME}/* /etc/icinga2/pki/

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

    cat << EOF >> ${api_file}

object ApiUser "${DASHING_API_USER}" {
  password    = "${DASHING_API_PASS}"
  client_cn   = NodeName
  permissions = [ "*" ]
}

EOF

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
