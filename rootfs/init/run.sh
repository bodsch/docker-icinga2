#!/bin/bash
#
#

[ ${DEBUG} ] && set -x

HOSTNAME=$(hostname -f)

export ICINGA_CERT_DIR="/etc/icinga2/certs"
ICINGA_LIB_DIR="/var/lib/icinga2"

ICINGA_VERSION=$(icinga2 --version | head -n1 | awk -F 'version: ' '{printf $2}' | awk -F \. {'print $1 "." $2'} | sed 's|r||')
[ "${ICINGA_VERSION}" = "2.8" ] && export ICINGA_CERT_DIR="/var/lib/icinga2/certs"

export ICINGA_VERSION
export ICINGA_CERT_DIR
export ICINGA_LIB_DIR
export HOSTNAME

. /init/output.sh

# -------------------------------------------------------------------------------------------------

# side channel to inject some wild-style customized scripts
# THIS CAN BREAK THE COMPLETE ICINGA2 CONFIGURATION!
#
custom_scripts() {

  if [ -d /init/custom.d ]
  then
    for f in /init/custom.d/*
    do
      case "$f" in
        *.sh)
          log_warn "------------------------------------------------------"
          log_warn "YOU SHOULD KNOW WHAT YOU'RE DOING."
          log_warn "THIS CAN BREAK THE COMPLETE ICINGA2 CONFIGURATION!"
          log_warn "RUN SCRIPT: ${f}";
          nohup "${f}" > /dev/stdout 2>&1 &
          log_warn "------------------------------------------------------"
          ;;
        *)
          log_warn "ignoring file ${f}"
          ;;
      esac
      echo
    done
  fi
}


detect_type() {

  if ( [ -z ${ICINGA_PARENT} ] && [ ! -z ${ICINGA_MASTER} ] && [ "${ICINGA_MASTER}" == "${HOSTNAME}" ] )
  then
    ICINGA_TYPE="Master"
  elif ( [ ! -z ${ICINGA_PARENT} ] && [ ! -z ${ICINGA_MASTER} ] && [ "${ICINGA_MASTER}" == "${ICINGA_PARENT}" ] )
  then
    ICINGA_TYPE="Satellite"
  else
    ICINGA_TYPE="Agent"
  fi
  export ICINGA_TYPE
}


run() {

  detect_type

  log_info "---------------------------------------------------"
  log_info "   Icinga ${ICINGA_TYPE} Version ${ICINGA_VERSION} - build: ${BUILD_DATE}"
  log_info " ---------------------------------------------------"

  . /init/common.sh

  prepare

  . /init/database/mysql.sh
  . /init/configure_icinga.sh
  . /init/api_user.sh
  . /init/graphite_setup.sh
  . /init/configure_ssmtp.sh

  correct_rights

  custom_scripts

  log_info "start init process ..."

  if [[ "${ICINGA_TYPE}" = "Master" ]]
  then
    export RAILS_ENV="production"
    # backup the generated zones
    #
    nohup /init/runtime/inotify.sh > /dev/stdout 2>&1 &
    nohup /usr/local/bin/rest-service.rb > /dev/stdout 2>&1 &
  else
    # nohup /init/runtime/ca_validator.sh > /dev/stdout 2>&1 &

    nohup /init/runtime/zone_watcher.sh > /dev/stdout 2>&1 &
  fi

  /usr/sbin/icinga2 \
    daemon \
      --config /etc/icinga2/icinga2.conf \
      --errorlog /dev/stdout
}


run

# EOF
