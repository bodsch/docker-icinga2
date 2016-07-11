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

CARBON_HOST=${CARBON_HOST:-""}
CARBON_PORT=${CARBON_PORT:-2003}

IDO_PASSWORD=${IDO_PASSWORD:-$(pwgen -s 15 1)}

USER=
GROUP=


if [ -z ${MYSQL_HOST} ]
then
  echo " [E] no MYSQL_HOST var set ..."
  exit 1
fi

mysql_opts="--host=${MYSQL_HOST} --user=${MYSQL_ROOT_USER} --password=${MYSQL_ROOT_PASS} --port=${MYSQL_PORT}"


waitForDatabase() {

  # wait for needed database
  while ! nc -z ${MYSQL_HOST} ${MYSQL_PORT}
  do
    sleep 3s
  done

  # must start initdb and do other jobs well
  echo " [i] wait for database for there initdb and do other jobs well"
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


configureAPICert() {

  # icinga2 API cert - regenerate new private key and certificate when running in a new container
  if [ -d ${WORK_DIR}/pki ]
  then
    echo " [i] restore older PKI settings"
    cp -ar ${WORK_DIR}/pki /etc/icinga2/

    icinga2 feature enable api
  fi

  sed -i "s,^.*\ NodeName\ \=\ .*,const\ NodeName\ \=\ \"${HOSTNAME}\",g" /etc/icinga2/constants.conf

  # icinga2 API cert - regenerate new private key and certificate when running in a new container
  if [ ! -f /etc/icinga2/pki/${HOSTNAME}.key ]
  then
    echo " [i] Generating new private key and certificate for this container ${HOSTNAME} ..."

    PKI_KEY="/etc/icinga2/pki/${HOSTNAME}.key"
    PKI_CSR="/etc/icinga2/pki/${HOSTNAME}.csr"
    PKI_CRT="/etc/icinga2/pki/${HOSTNAME}.crt"

    icinga2 api setup
    icinga2 pki new-cert --cn ${HOSTNAME} --key ${PKI_KEY} --csr ${PKI_CSR}
    icinga2 pki sign-csr --csr ${PKI_CSR} --cert ${PKI_CRT}

    cp -ar /etc/icinga2/pki ${WORK_DIR}/

    echo " [i] Finished cert generation"
  fi

}


configureDatabase() {

  local logfile="${WORK_DIR}/icinga2-ido-mysql-schema.log"
  local status="${WORK_DIR}/mysql-schema.import"

  if [ ! -f ${status} ]
  then
    echo " [i] Initializing databases and icinga2 configurations."
    echo " [i] This may take a few minutes"

#    ICINGAADMIN_PASSWORD=$(openssl passwd -1 "icinga")

    (
      echo "--- create user 'icinga2'@'%' IDENTIFIED BY '${IDO_PASSWORD}';"
      echo "CREATE DATABASE IF NOT EXISTS icinga2;"
      echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icinga2.* TO 'icinga2'@'%' IDENTIFIED BY '${IDO_PASSWORD}';"
      echo "FLUSH PRIVILEGES;"
    ) | mysql ${mysql_opts}

    mysql ${mysql_opts} --force icinga2  < /usr/share/icinga2-ido-mysql/schema/mysql.sql  >> ${logfile} 2>&1

    if [ $? -eq 0 ]
    then
      touch ${status}
    else
      echo " [E] can't insert the icinga2 Database Schema"
      exit 1
    fi

    sed -i 's|//host \= \".*\"|host \=\ \"'${MYSQL_HOST}'\"|g'             /etc/icinga2/features-available/ido-mysql.conf
    sed -i 's|//password \= \".*\"|password \= \"'${IDO_PASSWORD}'\"|g'    /etc/icinga2/features-available/ido-mysql.conf
    sed -i 's|//user =\ \".*\"|user =\ \"icinga2\"|g'                      /etc/icinga2/features-available/ido-mysql.conf
    sed -i 's|//database =\ \".*\"|database =\ \"icinga2\"|g'              /etc/icinga2/features-available/ido-mysql.conf
  fi
}


configureAPIUser() {

  local api_file="/etc/icinga2/conf.d/api-users.conf"

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
    configureAPICert
    configureAPIUser

    configureDatabase

    correctRights

    echo -e "\n"
    echo " ==================================================================="
    echo " MySQL user 'icinga2' password set to ${IDO_PASSWORD}"
    echo " ==================================================================="
    echo ""
  fi

  startSupervisor
}


run

# EOF
