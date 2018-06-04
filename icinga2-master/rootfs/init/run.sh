#!/bin/bash
#
#

. /etc/profile

# set -e

[[ ${DEBUG} ]] && set -x
[[ -f /etc/environment ]] && . /etc/environment

HOSTNAME=$(hostname -f)

export ICINGA2_CERT_DIRECTORY="/etc/icinga2/certs"
ICINGA2_LIB_DIRECTORY="/var/lib/icinga2"

ICINGA2_VERSION=$(icinga2 --version | head -n1 | awk -F 'version: ' '{printf $2}' | awk -F \. {'print $1 "." $2'} | sed 's|r||')
[[ "${ICINGA2_VERSION}" = "2.8" ]] && export ICINGA2_CERT_DIRECTORY="/var/lib/icinga2/certs"

export ICINGA2_VERSION
export ICINGA2_CERT_DIRECTORY
export ICINGA2_LIB_DIRECTORY
export HOSTNAME

. /init/output.sh
. /init/runtime/service_handler.sh
[[ -f /usr/bin/vercomp ]] && . /usr/bin/vercomp

# -------------------------------------------------------------------------------------------------

# side channel to inject some wild-style customized scripts
# THIS CAN BREAK THE COMPLETE ICINGA2 CONFIGURATION!
#
custom_scripts() {

  if [[ -d /init/custom.d ]]
  then
    for f in /init/custom.d/*
    do
      case "$f" in
        *.sh)
          log_WARN "------------------------------------------------------"
          log_WARN "RUN SCRIPT: ${f}"
          log_WARN "YOU SHOULD KNOW WHAT YOU'RE DOING."
          log_WARN "THIS CAN BREAK THE COMPLETE ICINGA2 CONFIGURATION!"
          nohup "${f}" > /dev/stdout 2>&1 &
          log_WARN "------------------------------------------------------"
          ;;
        *)
          log_warn "ignoring file ${f}"
          ;;
      esac
      echo
    done
  fi
}


# detect_type() {
#
#   if ( [[ -z ${ICINGA2_PARENT} ]] && [[ ! -z ${ICINGA2_MASTER} ]] && [[ "${ICINGA2_MASTER}" == "${HOSTNAME}" ]] )
#   then
#     ICINGA2_TYPE="Master"
#   elif ( [[ ! -z ${ICINGA2_PARENT} ]] && [[ ! -z ${ICINGA2_MASTER} ]] && [[ "${ICINGA2_MASTER}" == "${ICINGA2_PARENT}" ]] )
#   then
#     ICINGA2_TYPE="Satellite"
#   else
#     ICINGA2_TYPE="Agent"
#   fi
#   export ICINGA2_TYPE
# }


run() {

#   detect_type

  log_info "---------------------------------------------------"
  log_info "   Icinga ${ICINGA2_TYPE} Version ${BUILD_VERSION} - build: ${BUILD_DATE}"
  log_info "---------------------------------------------------"

  . /init/common.sh

  prepare

  . /init/consul.sh

  validate_certservice_environment

  . /init/database/mysql.sh
  . /init/configure_icinga.sh
  . /init/api_user.sh
  . /init/graphite_setup.sh
  . /init/configure_ssmtp.sh

  correct_rights

  custom_scripts

  log_info "start init process ..."

  if [[ "${ICINGA2_TYPE}" = "Master" ]]
  then
    # backup the generated zones
    #
    nohup /init/runtime/inotify.sh > /dev/stdout 2>&1 &

    # env | grep ICINGA | sort
    nohup /usr/local/icinga2-cert-service/bin/icinga2-cert-service.rb > /dev/stdout 2>&1 &
  else
    :
    nohup /init/runtime/ca_validator.sh > /dev/stdout 2>&1 &

    if [[ ! -e /tmp/final ]]
    then
      nohup /init/runtime/zone_watcher.sh > /dev/stdout 2>&1 &
    fi
  fi

  /usr/sbin/icinga2 \
    daemon \
    --config /etc/icinga2/icinga2.conf \
    --errorlog /dev/stdout
}

run

# EOF
