#!/bin/bash
#
#

set -e
set -u

. /etc/profile

# if [[ -z ${var+x} ]]; then echo "var is unset"; else echo "var is set to '$var'"; fi
if [[ -z ${DEBUG+x} ]]
then
  if [[ "${DEBUG}" = "true" ]] || [[ ${DEBUG} -eq 1 ]]
  then
    set -x
  fi
fi



[[ ${DEBUG} ]] && set -x
[[ -f /etc/environment ]] && . /etc/environment

# HOSTNAME=$(hostname -f)
#
# export ICINGA2_CERT_DIRECTORY="/etc/icinga2/certs"
# ICINGA2_LIB_DIRECTORY="/var/lib/icinga2"
#
# ICINGA2_VERSION=$(icinga2 --version | head -n1 | awk -F 'version: ' '{printf $2}' | awk -F \. {'print $1 "." $2'} | sed 's|r||')
# [[ "${ICINGA2_VERSION}" = "2.8" ]] && export ICINGA2_CERT_DIRECTORY="/var/lib/icinga2/certs"
#
# export ICINGA2_VERSION
# export ICINGA2_CERT_DIRECTORY
# export ICINGA2_LIB_DIRECTORY
# export HOSTNAME

. /init/output.sh
. /init/consul.sh
. /init/environments.sh
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
  log_info " Icinga ${ICINGA2_TYPE} Version ${BUILD_VERSION} - build: ${BUILD_DATE}"
  log_info "---------------------------------------------------"

  . /init/common.sh

  prepare

#  . /init/consul.sh

  validate_certservice_environment

  version_of_icinga_master

  if [[ "${ICINGA2_TYPE}" = "Master" ]] && . /init/database/mysql.sh
  . /init/configure_icinga.sh
  . /init/api_user.sh
  if [[ "${ICINGA2_TYPE}" = "Master" ]] && . /init/graphite_setup.sh
  if [[ "${ICINGA2_TYPE}" = "Master" ]] && . /init/configure_ssmtp.sh

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

  if [[ "${CONFIG_BACKEND}" = "consul" ]]
  then
    wait_for_consul
    register_node
    set_consul_var  "${HOSTNAME}/version" ${ICINGA2_VERSION}
    set_consul_var  "${HOSTNAME}/cert-service/ba/user"      ${CERT_SERVICE_BA_USER}
    set_consul_var  "${HOSTNAME}/cert-service/ba/password"  ${CERT_SERVICE_BA_PASSWORD}
    set_consul_var  "${HOSTNAME}/cert-service/api/user"     ${CERT_SERVICE_API_USER}
    set_consul_var  "${HOSTNAME}/cert-service/api/password" ${CERT_SERVICE_API_PASSWORD}
    set_consul_var  "${HOSTNAME}/database/ido/user"         'icinga2'
    set_consul_var  "${HOSTNAME}/database/ido/password"     ${IDO_PASSWORD}
    set_consul_var  "${HOSTNAME}/database/ido/schema"       ${IDO_DATABASE_NAME}
#    set_consul_var  "${HOSTNAME}/api/users/"                ""
  fi



  /usr/sbin/icinga2 \
    daemon \
    --config /etc/icinga2/icinga2.conf \
    --errorlog /dev/stdout
}

run

# EOF
