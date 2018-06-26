#!/bin/bash
#
#

set -e
set -u

finish() {
  rv=$?
  echo -e "\033[38;5;202m\033[1mexit with signal '${rv}'\033[0m"
  sleep 4s
  exit $rv
}

trap finish SIGINT SIGTERM INT TERM EXIT

. /etc/profile

# if [[ -z ${DEBUG+x} ]]; then echo "DEBUG is unset"; else echo "DEBUG is set to '$DEBUG'"; fi

if [[ ! -z ${DEBUG+x} ]]
then
  if [[ "${DEBUG}" = "true" ]] || [[ ${DEBUG} -eq 1 ]]
  then
    set -x
  fi
fi

[[ -f /etc/environment ]] && . /etc/environment

. /init/output.sh
. /init/environment.sh
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


run() {

  log_info "prepare system"

  . /init/common.sh

  prepare

  validate_certservice_environment

  version_of_icinga_master

  [[ "${ICINGA2_TYPE}" = "Master" ]] && . /init/database/mysql.sh

  . /init/configure_icinga.sh
  . /init/api_user.sh

  if [[ "${ICINGA2_TYPE}" = "Master" ]]
  then
    . /init/graphite_setup.sh
    . /init/configure_ssmtp.sh
  fi

  correct_rights

  log_info "---------------------------------------------------"
  log_info " Icinga ${ICINGA2_TYPE} Version ${ICINGA2_VERSION} - build: ${BUILD_DATE}"
  log_info "---------------------------------------------------"

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
