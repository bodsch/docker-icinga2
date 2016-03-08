#!/bin/sh

initfile=/opt/run.init

MYSQL_HOST=${MYSQL_HOST:-""}
MYSQL_PORT=${MYSQL_PORT:-""}
MYSQL_USER=${MYSQL_USER:-"root"}
MYSQL_PASS=${MYSQL_PASS:-""}

CARBON_HOST=${CARBON_HOST:-""}
CARBON_PORT=${CARBON_PORT:-2003}

if [ -z ${MYSQL_HOST} ]
then
  echo " [E] no MYSQL_HOST var set ..."
  exit 1
fi

mysql_opts="--host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASS} --port=${MYSQL_PORT}"

# wait for needed database
while ! nc -z ${MYSQL_HOST} ${MYSQL_PORT}
do
  sleep 3s
done

# must start initdb and do other jobs well
sleep 10s

# -------------------------------------------------------------------------------------------------

#env | grep BLUEPRINT  > /etc/env.vars
#env | grep HOST_     >> /etc/env.vars

chmod 1777 /tmp

USER=
GROUP=

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

if ( [ -z ${USER} ] || [ -z ${GROUP} ] )
then
  echo "No User/Group nagios/icinga found!"
else
  chown -R ${USER}:root     /etc/icinga2
  chown -R ${USER}:${GROUP} /var/lib/icinga2
fi

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

chown -R ${USER}:${GROUP} ${ICINGA2_RUN_DIR}/icinga2

if [ ! -f "${initfile}" ]
then
  # Passwords...
  IDO_PASSWORD=${IDO_PASSWORD:-$(pwgen -s 15 1)}

  # remove var.os to disable ssh-checks
  if [ -f /etc/icinga2/conf.d/hosts.conf ]
  then
    sed -i -e "s,^.*\ vars.os\ \=\ .*,  //\ vars.os = \"Linux\",g" /etc/icinga2/conf.d/hosts.conf
  fi

  # enable icinga2 features if not already there
  echo " [i] Enabling icinga2 features."
  icinga2 feature enable ido-mysql command livestatus compatlog checker mainlog icingastatus

  if [ ! -z ${CARBON_HOST} ]
  then
    icinga2 feature enable graphite

    if [ -e /etc/icinga2/features-enabled/graphite.conf ]
    then
      sed -i "s,^.*\ //host\ =\ .*,  host\ =\ \"${CARBON_HOST}\",g" /etc/icinga2/features-enabled/graphite.conf
      sed -i "s,^.*\ //port\ =\ .*,  port\ =\ \"${CARBON_PORT}\",g" /etc/icinga2/features-enabled/graphite.conf
    fi
  fi

  chown ${USER}:${GROUP} /etc/icinga2/features-available/ido-mysql.conf

  # https://www.axxeo.de/blog/technisches/icinga2-livestatus-ueber-tcp.html

  #icinga2 API cert - regenerate new private key and certificate when running in a new container
  if [ ! -f /etc/icinga2/pki/${HOSTNAME}.key ]
  then
    echo " [i] Generating new private key and certificate for this container ${HOSTNAME} ..."

    PKI_KEY="/etc/icinga2/pki/${HOSTNAME}.key"
    PKI_CSR="/etc/icinga2/pki/${HOSTNAME}.csr"
    PKI_CRT="/etc/icinga2/pki/${HOSTNAME}.crt"

    icinga2 api setup
    sed -i "s,^.*\ NodeName\ \=\ .*,const\ NodeName\ \=\ \"${HOSTNAME}\",g" /etc/icinga2/constants.conf
    icinga2 pki new-cert --cn ${HOSTNAME} --key ${PKI_KEY} --csr ${PKI_CSR}
    icinga2 pki sign-csr --csr ${PKI_CSR} --cert ${PKI_CRT}
    echo " => Finished cert generation"
  fi

  echo " => Initializing databases and icinga2 configurations."
  echo " => This may take a few minutes"

  ICINGAADMIN_PASSWORD=$(openssl passwd -1 "icinga")

  (
    echo "--- create user 'icinga2'@'%' IDENTIFIED BY '${IDO_PASSWORD}';"
    echo "CREATE DATABASE IF NOT EXISTS icinga2;"
    echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icinga2.* TO 'icinga2'@'%' IDENTIFIED BY '${IDO_PASSWORD}';"
  ) | mysql ${mysql_opts}

  mysql ${mysql_opts} --force icinga2  < /usr/share/icinga2-ido-mysql/schema/mysql.sql                   >> /opt/icinga2-ido-mysql-schema.log 2>&1

  sed -i 's|//host \= \".*\"|host \=\ \"'${MYSQL_HOST}'\"|g'             /etc/icinga2/features-available/ido-mysql.conf
  sed -i 's|//password \= \".*\"|password \= \"'${IDO_PASSWORD}'\"|g'    /etc/icinga2/features-available/ido-mysql.conf
  sed -i 's|//user =\ \".*\"|user =\ \"icinga2\"|g'                      /etc/icinga2/features-available/ido-mysql.conf
  sed -i 's|//database =\ \".*\"|database =\ \"icinga2\"|g'              /etc/icinga2/features-available/ido-mysql.conf

  touch ${initfile}

  echo -e "\n"
  echo " ==================================================================="
  echo " MySQL user 'icinga2' password set to ${IDO_PASSWORD}"
  echo " ==================================================================="
  echo ""

fi

echo -e "\n Starting Supervisor.\n  You can safely CTRL-C and the container will continue to run with or without the -d (daemon) option\n\n"

if [ -f /etc/supervisor.d/icinga2.ini ]
then
    /usr/bin/supervisord >> /dev/null
else
  exec /bin/bash
fi

# EOF
