#!/bin/sh
#
#

if [ ${DEBUG} ]
then
  set -x
fi

WORK_DIR=/srv/icinga2

MYSQL_HOST=${MYSQL_HOST:-""}
MYSQL_PORT=${MYSQL_PORT:-"3306"}

MYSQL_ROOT_USER=${MYSQL_ROOT_USER:-"root"}
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-""}
MYSQL_OPTS=

ICINGA_CLUSTER=${ICINGA_CLUSTER:-false}
ICINGA_MASTER=${ICINGA_MASTER:-""}

CARBON_HOST=${CARBON_HOST:-""}
CARBON_PORT=${CARBON_PORT:-2003}

IDO_DATABASE_NAME=${IDO_DATABASE_NAME:-"icinga2core"}
IDO_PASSWORD=${IDO_PASSWORD:-$(pwgen -s 15 1)}

USER=
GROUP=

HOSTNAME=$(hostname -f)

# -------------------------------------------------------------------------------------------------

prepare() {

  [ -d ${WORK_DIR} ] || mkdir -p ${WORK_DIR}

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

  # remove var.os to disable ssh-checks
  if [ -f /etc/icinga2/conf.d/hosts.conf ]
  then
    sed -i -e "s,^.*\ vars.os\ \=\ .*,  //\ vars.os = \"Linux\",g" /etc/icinga2/conf.d/hosts.conf
  fi
}


# enable Icinga2 Feature
#
enableIcingaFeature() {

  local feature="${1}"

  if [ $(icinga2 feature list | grep Enabled | grep -c ${feature}) -eq 0 ]
  then
    icinga2 feature enable ${feature}
  fi
}


correctRights() {

  chmod 1777 /tmp

  if ( [ -z ${USER} ] || [ -z ${GROUP} ] )
  then
    echo " [E] No User/Group nagios or icinga found!"
  else

    [ -f /var/lib/icinga2/api/log/current ] && rm -f /var/lib/icinga2/api/log/current
    [ -d /var/lib/icinga2/api/log/current ] || mkdir -p /var/lib/icinga2/api/log/current

    chown -R ${USER}:root     /etc/icinga2
    chown -R ${USER}:${GROUP} /var/lib/icinga2
    chown -R ${USER}:${GROUP} ${ICINGA2_RUN_DIR}/icinga2
  fi
}


startSupervisor() {

#  echo -e "\n Starting Supervisor.\n\n"

  if [ -f /etc/supervisord.conf ]
  then
    /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
  else
    echo "no '/etc/supervisord.conf' found"
    exit 1
  fi
}


run() {

  prepare

  . /init/database/mysql.sh
  . /init/pki_setup.sh
  . /init/api_user.sh
  . /init/graphite_setup.sh
  . /init/configure_ssmtp.sh

  correctRights

  startSupervisor
}


run

# EOF
