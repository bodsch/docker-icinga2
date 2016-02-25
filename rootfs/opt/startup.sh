#!/bin/bash

set -e

initfile=/opt/run.init

MYSQL_HOST=${MYSQL_HOST:-""}
MYSQL_USER=${MYSQL_USER:-"root"}
MYSQL_PASS=${MYSQL_PASS:-""}

env | grep BLUEPRINT  > /etc/env.vars
env | grep HOST_     >> /etc/env.vars

chmod 1777 /tmp

chown -R nagios:root /etc/icinga2
chown nagios:nagios /etc/icinga2/features-available/ido-mysql.conf
chown -R nagios:nagios /var/lib/icinga2

if [ -z ${MYSQL_HOST} ]
then
  echo "no '${MYSQL_HOST}' ..."
  exit 1
fi

mysql_opts="--host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASS} --port=3306"

if [ ! -f "${initfile}" ]
then
  # Passwords...

  ICINGA_PASSWORD=${ICINGA_PASSWORD:-$(pwgen -s 15 1)}
  IDO_PASSWORD=${IDO_PASSWORD:-$(pwgen -s 15 1)}




  # disable ssh-checks
  sed -i -e "s,^.*\ vars.os\ \=\ .*,  //\ vars.os = \"Linux\",g" /etc/icinga2/conf.d/hosts.conf

  # enable icinga2 features if not already there
  echo " => Enabling icinga2 features."
  icinga2 feature enable ido-mysql command livestatus compatlog

  #icinga2 API cert - regenerate new private key and certificate when running in a new container
  if [ ! -f /etc/icinga2/pki/${HOSTNAME}.key ]
  then
    echo " => Generating new private key and certificate for this container ${HOSTNAME} ..."

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
    echo "CREATE DATABASE IF NOT EXISTS icinga;"
    echo "CREATE DATABASE IF NOT EXISTS icinga2idomysql;"
    echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icinga.* TO 'icinga'@'localhost' IDENTIFIED BY '${ICINGA_PASSWORD}';"
    echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icinga2idomysql.* TO 'icinga2-ido-mysq'@'localhost' IDENTIFIED BY '${IDO_PASSWORD}';"
  ) | mysql ${mysql_opts}

  mysql ${mysql_opts} --force icinga          < /usr/share/icinga2-ido-mysql/schema/mysql.sql                   >> /opt/icinga2-ido-mysql-schema.log 2>&1
  mysql ${mysql_opts} --force icinga2idomysql < /usr/share/dbconfig-common/data/icinga2-ido-mysql/install/mysql >> /opt/icinga2-ido-mysql-schema.log 2>&1


















else
  :

fi


exec /bin/bash

# EOF

