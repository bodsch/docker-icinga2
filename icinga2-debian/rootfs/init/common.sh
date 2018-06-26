#

version_string() {
  echo "${1}" | sed 's|r||' | awk -F '-' '{print $1}'
}

# compare the version of the Icinga2 Master with the Satellite
#
version_of_icinga_master() {

  [[ "${ICINGA2_TYPE}" = "Master" ]] && return

  . /init/wait_for/icinga_master.sh

  # get the icinga2 version of our master
  #
  log_info "compare our version with the master '${ICINGA2_MASTER}'"
  code=$(curl \
    --user ${CERT_SERVICE_API_USER}:${CERT_SERVICE_API_PASSWORD} \
    --silent \
    --location \
    --header 'Accept: application/json' \
    --request GET \
    --insecure \
    https://${ICINGA2_MASTER}:5665/v1/status/IcingaApplication )

  if [[ $? -eq 0 ]]
  then
    version=$(echo "${code}" | jq --raw-output '.results[].status.icingaapplication.app.version' 2> /dev/null)

    version=$(version_string ${version})

    vercomp ${version} ${ICINGA2_VERSION}
    case $? in
        0) op='=';;
        1) op='>';;
        2) op='<';;
    esac

    if [[ "${op}" != "=" ]]
    then
      if [[ "${op}" = "<" ]]
      then
        log_warn "The version of the master is smaller than that of the satellite!"
      elif [[ "${op}" = ">" ]]
      then
        log_warn "The version of the master is higher than that of the satellite!"
      fi

      log_warn "The version of the master differs from that of the satellite! (master: ${version} / satellite: ${BUILD_VERSION})"
      log_warn "Which can lead to problems!"
    else
      log_info "The versions between Master and Satellite are identical"
    fi
  fi
}




# prepare the system and icinga to run in the docker environment
#
prepare() {

  [[ -d ${ICINGA2_LIB_DIRECTORY}/backup ]] || mkdir -p ${ICINGA2_LIB_DIRECTORY}/backup
  [[ -d ${ICINGA2_CERT_DIRECTORY} ]] || mkdir -p ${ICINGA2_CERT_DIRECTORY}

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

    ICINGA2_RUN_DIRECTORY=${ICINGA2_RUN_DIR}
    ICINGA2_LOG_DIRECTORY=${ICINGA2_LOG}
  #  ICINGA2_RUNasUSER=${ICINGA2_USER}
  #  ICINGA2_RUNasGROUP=${ICINGA2_GROUP}
  else
    ICINGA2_RUN_DIRECTORY=$(/usr/sbin/icinga2 variable get RunDir)
    ICINGA2_LOG_DIRECTORY="/var/log/icinga2/icinga2.log"
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

  # create directory for the logfile and change rights
  #
  LOGDIR=$(dirname ${ICINGA2_LOG_DIRECTORY})

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
    chown -R ${USER}:${GROUP} ${ICINGA2_RUN_DIRECTORY}/icinga2
    chown -R ${USER}:${GROUP} ${ICINGA2_CERT_DIRECTORY}
  fi
}

random() {
  echo $(shuf -i 5-30 -n 1)
}

curl_opts() {

  opts=""
  opts="${opts} --user ${CERT_SERVICE_API_USER}:${CERT_SERVICE_API_PASSWORD}"
  opts="${opts} --silent"
  opts="${opts} --location"
  opts="${opts} --insecure"

  echo ${opts}
}


validate_certservice_environment() {

  CERT_SERVICE_BA_USER=${CERT_SERVICE_BA_USER:-"admin"}
  CERT_SERVICE_BA_PASSWORD=${CERT_SERVICE_BA_PASSWORD:-"admin"}
  CERT_SERVICE_API_USER=${CERT_SERVICE_API_USER:-""}
  CERT_SERVICE_API_PASSWORD=${CERT_SERVICE_API_PASSWORD:-""}
  CERT_SERVICE_SERVER=${CERT_SERVICE_SERVER:-"localhost"}
  CERT_SERVICE_PORT=${CERT_SERVICE_PORT:-"80"}
  CERT_SERVICE_PATH=${CERT_SERVICE_PATH:-"/"}
  USE_CERT_SERVICE=false

  # use the new Cert Service to create and get a valide certificat for distributed icinga services
  #
  if (
    [[ ! -z ${CERT_SERVICE_BA_USER} ]] &&
    [[ ! -z ${CERT_SERVICE_BA_PASSWORD} ]] &&
    [[ ! -z ${CERT_SERVICE_API_USER} ]] &&
    [[ ! -z ${CERT_SERVICE_API_PASSWORD} ]]
  )
  then
    USE_CERT_SERVICE=true

    export CERT_SERVICE_BA_USER
    export CERT_SERVICE_BA_PASSWORD
    export CERT_SERVICE_API_USER
    export CERT_SERVICE_API_PASSWORD
    export CERT_SERVICE_SERVER
    export CERT_SERVICE_PORT
    export CERT_SERVICE_PATH
    export USE_CERT_SERVICE
  fi
}
