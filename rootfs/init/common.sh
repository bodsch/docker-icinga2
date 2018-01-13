#

DEMO_DATA=${DEMO_DATA:-'false'}
USER=
GROUP=
ICINGA_MASTER=${ICINGA_MASTER:-''}

# prepare the system and icinga to run in the docker environment
#
prepare() {

  [[ -d ${ICINGA_LIB_DIR}/backup ]] || mkdir -p ${ICINGA_LIB_DIR}/backup
  [[ -d ${ICINGA_CERT_DIR} ]] || mkdir -p ${ICINGA_CERT_DIR}

  # detect username
  #
  for u in nagios icinga
  do
    if [[ "$(getent passwd ${u})" ]]
    then
      USER="${u}"
      break
    fi
  done

  # detect groupname
  #
  for g in nagios icinga
  do
    if [[ "$(getent group ${g})" ]]
    then
      GROUP="${g}"
      break
    fi
  done

  # read (generated) icinga2.sysconfig and import environment
  # otherwise define variables
  #
  if [[ -f /etc/icinga2/icinga2.sysconfig ]]
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
  #
  [[ -f /etc/icinga2/conf.d/hosts.conf ]] && sed -i -e "s|^.*\ vars.os\ \=\ .*|  vars.os = \"Docker\"|g" /etc/icinga2/conf.d/hosts.conf

  [[ -f /etc/icinga2/conf.d/services.conf ]] && mv /etc/icinga2/conf.d/services.conf /etc/icinga2/conf.d/services.conf-distributed
  [[ -f /etc/icinga2/conf.d/services.conf.docker ]] && cp /etc/icinga2/conf.d/services.conf.docker /etc/icinga2/conf.d/services.conf

  # set NodeName (important for the cert feature!)
  #
  sed -i "s|^.*\ NodeName\ \=\ .*|const\ NodeName\ \=\ \"${HOSTNAME}\"|g" /etc/icinga2/constants.conf

  # create global zone directories for distributed monitoring
  #
  [[ -d /etc/icinga2/zones.d/global-templates ]] || mkdir -p /etc/icinga2/zones.d/global-templates
  [[ -d /etc/icinga2/zones.d/director-global ]] || mkdir -p /etc/icinga2/zones.d/director-global

  # create directory for the logfile and change rights
  #
  LOGDIR=$(dirname ${ICINGA2_LOG})

  [[ -d ${LOGDIR} ]] || mkdir -p ${LOGDIR}

  chown  ${USER}:${GROUP} ${LOGDIR}
  chmod  ug+wx ${LOGDIR}
  find ${LOGDIR} -type f -exec chmod ug+rw {} \;

  # install demo data
  #
  if [[ "${DEMO_DATA}" = "true" ]]
  then
    cp -fua /init/demo /etc/icinga2/

    sed \
      -i \
      -e \
      's|// include_recursive "demo"|include_recursive "demo"|g' \
      /etc/icinga2/icinga2.conf
  fi
}

# enable Icinga2 Feature
#
enable_icinga_feature() {

  local feature="${1}"

  if [[ $(icinga2 feature list | grep Enabled | grep -c ${feature}) -eq 0 ]]
  then
    log_info "feature ${feature} enabled"
    icinga2 feature enable ${feature} > /dev/null
  fi
}

# disable Icinga2 Feature
#
disable_icinga_feature() {

  local feature="${1}"

  if [[ $(icinga2 feature list | grep Enabled | grep -c ${feature}) -eq 1 ]]
  then
    log_info "feature ${feature} disabled"
    icinga2 feature disable ${feature} > /dev/null
  fi
}

# correct rights of files and directories
#
correct_rights() {

  chmod 1777 /tmp

  if ( [[ -z ${USER} ]] || [[ -z ${GROUP} ]] )
  then
    log_error "no nagios or icinga user/group found!"
  else
    [[ -e /var/lib/icinga2/api/log/current ]] && rm -rf /var/lib/icinga2/api/log/current

    chown -R ${USER}:root     /etc/icinga2
    chown -R ${USER}:${GROUP} /var/lib/icinga2
    chown -R ${USER}:${GROUP} ${ICINGA2_RUN_DIR}/icinga2
    chown -R ${USER}:${GROUP} ${ICINGA_CERT_DIR}
  fi
}

random() {
  echo $(shuf -i 5-30 -n 1)
}

curl_opts() {

  opts=""
  opts="${opts} --user ${ICINGA_CERT_SERVICE_API_USER}:${ICINGA_CERT_SERVICE_API_PASSWORD}"
  opts="${opts} --silent"
  opts="${opts} --insecure"

#  if [ -e ${ICINGA_CERT_DIR}/${HOSTNAME}.pem ]
#  then
#    opts="${opts} --capath ${ICINGA_CERT_DIR}"
#    opts="${opts} --cert ${ICINGA_CERT_DIR}/${HOSTNAME}.pem"
#    opts="${opts} --cacert ${ICINGA_CERT_DIR}/ca.crt"
#  fi

  echo ${opts}
}
