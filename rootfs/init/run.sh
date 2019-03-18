#!/bin/bash
#
#

set +e
set +u


finish() {
  rv=$?
  log_INFO "exit with signal '${rv}'"

  if [[ ${rv} -gt 0 ]]
  then
    sleep 4s
  fi

  if [[ "${DEBUG}" = "true" ]]
  then
    caller
  fi

  log_info ""

  exit ${rv}
}

trap finish SIGINT SIGTERM INT TERM EXIT

# -------------------------------------------------------------------------------------------------

. /etc/profile

. /init/output.sh
. /usr/bin/vercomp
. /init/environment.sh

# -------------------------------------------------------------------------------------------------

ICINGA2_PARAMS=

# if [[ -z ${DEBUG+x} ]]; then echo "DEBUG is unset"; else echo "DEBUG is set to '$DEBUG'"; fi

if [[ ! -z ${DEBUG+x} ]]
then
#  env | grep DEBUG
  if ( [[ "${DEBUG}" = true ]] ||  [[ "${DEBUG}" = "true" ]] || [[ ${DEBUG} -eq 1 ]] )
  then
    export DEBUG="true"
  else
    unset DEBUG
  fi
fi

ICINGA2_PARAMS="--log-level ${ICINGA2_LOGLEVEL}"

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



configure_modules() {

  log_info "configure modules"

  if [[ -d /init/modules.d ]]
  then
    for f in /init/modules.d/*
    do
      case "$f" in
        *.sh)
          log_info "  $(basename ${f} .sh)"
          . ${f}
          ;;
        *)
          # log_warn "ignoring file ${f}"
          ;;
      esac
    done
  fi
}

run() {

  log_info ""
  log_info "prepare system"

  . /init/common.sh

  prepare

  fix_sys_caps

  if [[ ! -z ${DEVELOPMENT_MODUS+x} ]] && [[ ${DEVELOPMENT_MODUS} = true ]] || [[ ${DEVELOPMENT_MODUS} -eq 1 ]]
  then
    log_debug "DEVELOPMENT_MODUS is activ"

    tail -f /dev/null
  fi

  validate_certservice_environment

  version_of_icinga_master

  # create and configure database
  #
  [[ "${ICINGA2_TYPE}" = "Master" ]] && . /init/database/mysql.sh

  . /init/configure_icinga.sh
  . /init/api_user.sh

  # modules
  #
  [[ "${ICINGA2_TYPE}" = "Master" ]] && configure_modules

  correct_rights

  log_info "----------------------------------------------------"
  log_info " Icinga ${ICINGA2_TYPE} Version ${ICINGA2_VERSION} - build: ${BUILD_DATE}"
  log_info "----------------------------------------------------"

  custom_scripts

  if [[ "${ICINGA2_TYPE}" = "Master" ]]
  then
    # backup the generated zones
    #
    nohup /init/runtime/inotify.sh > /dev/stdout 2>&1 &
    nohup /init/runtime/watch_satellites.sh > /dev/stdout 2>&1 &

    # env | grep ICINGA | sort
    if [[ -f /usr/local/icinga2-cert-service/bin/icinga2-cert-service.rb ]]
    then
      nohup /usr/local/icinga2-cert-service/bin/icinga2-cert-service.rb > /dev/stdout 2>&1 &
    fi

  else
    #
    nohup /init/runtime/ca_validator.sh > /dev/stdout 2>&1 &

    if [[ ! -e /tmp/final ]]
    then
      nohup /init/runtime/zone_watcher.sh > /dev/stdout 2>&1 &
    fi
  fi


  log_info "start init process ..."

  /usr/sbin/icinga2 \
    daemon \
    ${ICINGA2_PARAMS}



}

run

# EOF
