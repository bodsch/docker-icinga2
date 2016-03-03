#!/bin/bash

initfile=/opt/run.init

MYSQL_HOST=${MYSQL_HOST:-""}
MYSQL_PORT=${MYSQL_PORT:-""}
MYSQL_USER=${MYSQL_USER:-"root"}
MYSQL_PASS=${MYSQL_PASS:-""}

if [ -z ${MYSQL_HOST} ]
then
  echo " [E] no '${MYSQL_HOST}' ..."
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

env | grep BLUEPRINT  > /etc/env.vars
env | grep HOST_     >> /etc/env.vars

chmod 1777 /tmp

chown -R nagios:root   /etc/icinga2
chown -R nagios:nagios /var/lib/icinga2

if [ ! -f "${initfile}" ]
then
  # Passwords...

  IDO_PASSWORD=${IDO_PASSWORD:-$(pwgen -s 15 1)}

  # disable ssh-checks
  sed -i -e "s,^.*\ vars.os\ \=\ .*,  //\ vars.os = \"Linux\",g" /etc/icinga2/conf.d/hosts.conf

  # enable icinga2 features if not already there
  echo " [i] Enabling icinga2 features."
  icinga2 feature enable ido-mysql command livestatus compatlog

  chown nagios:nagios /etc/icinga2/features-available/ido-mysql.conf

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
    echo "create user 'icinga2'@'%' IDENTIFIED BY '${IDO_PASSWORD}';"
    echo "CREATE DATABASE IF NOT EXISTS icinga2;"
    echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icinga2.* TO 'icinga2'@'%' IDENTIFIED BY '${IDO_PASSWORD}';"
  ) | mysql ${mysql_opts}

  mysql ${mysql_opts} --force icinga2  < /usr/share/icinga2-ido-mysql/schema/mysql.sql                   >> /opt/icinga2-ido-mysql-schema.log 2>&1
  mysql ${mysql_opts} --force icinga2  < /usr/share/dbconfig-common/data/icinga2-ido-mysql/install/mysql >> /opt/icinga2-ido-mysql-schema.log 2>&1

  sed -i 's/host \= \".*\"/host \=\ \"'${MYSQL_HOST}'\"/g'             /etc/icinga2/features-available/ido-mysql.conf
  sed -i 's/password \= \".*\"/password \= \"'${IDO_PASSWORD}'\"/g'    /etc/icinga2/features-available/ido-mysql.conf
  sed -i 's/user =\ \".*\"/user =\ \"icinga2\"/g'                      /etc/icinga2/features-available/ido-mysql.conf
  sed -i 's/database =\ \".*\"/database =\ \"icinga2\"/g'              /etc/icinga2/features-available/ido-mysql.conf

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
