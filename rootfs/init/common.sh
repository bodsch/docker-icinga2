#


USER=
GROUP=

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
    ICINGA2_LOG="/var/log/icinga2/icinga2.log"
  #  ICINGA2_RUNasUSER=$(/usr/sbin/icinga2 variable get RunAsUser)
  #  ICINGA2_RUNasGROUP=$(/usr/sbin/icinga2 variable get RunAsGroup)
  fi

  # change var.os from 'Linux' to 'Docker' to disable ssh-checks
  if [ -f /etc/icinga2/conf.d/hosts.conf ]
  then
    sed -i -e "s,^.*\ vars.os\ \=\ .*,  vars.os = \"Docker\",g" /etc/icinga2/conf.d/hosts.conf
  fi

  LOGDIR=$(dirname ${ICINGA2_LOG})

  [ -d ${LOGDIR} ] || mkdir -p ${LOGDIR}

  chown ${USER}:${GROUP} ${LOGDIR}
  chmod ug+wx ${LOGDIR}   2> /dev/null
  chmod ug+rw ${LOGDIR}/* 2> /dev/null


  if ( [ ! -z ${ICINGA_MASTER} ] && [ "${ICINGA_MASTER}" != "${HOSTNAME}" ] )
  then
    # in first, we remove the startup script to start our cert-service
    # they is only needed at a master instance
    [ -d /etc/s6/icinga2-cert-service ] && rm -rf /etc/s6/icinga2-cert-service
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

    [ -e /var/lib/icinga2/api/log/current ] && rm -rf /var/lib/icinga2/api/log/current
#    [ -d /var/lib/icinga2/api/log/current ] || mkdir -p /var/lib/icinga2/api/log/current

    chown -R ${USER}:root     /etc/icinga2
    chown -R ${USER}:${GROUP} /var/lib/icinga2
    chown -R ${USER}:${GROUP} ${ICINGA2_RUN_DIR}/icinga2
  fi
}

