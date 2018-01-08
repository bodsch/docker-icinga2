#!/bin/sh
#
#

[ ${DEBUG} ] && set -x

HOSTNAME=$(hostname -f)

ICINGA_CERT_DIR="/etc/icinga2/certs"
ICINGA_LIB_DIR="/var/lib/icinga2"

ICINGA_VERSION=$(icinga2 --version | head -n1 | awk -F 'version: ' '{printf $2}' | awk -F \. {'print $1 "." $2'} | sed 's|r||')
[ "${ICINGA_VERSION}" = "2.8" ] && ICINGA_CERT_DIR="/var/lib/icinga2/certs"

export ICINGA_VERSION
export ICINGA_CERT_DIR
export ICINGA_LIB_DIR
export HOSTNAME

# -------------------------------------------------------------------------------------------------

custom_scripts() {

  if [ -d /init/custom.d ]
  then
    for f in /init/custom.d/*
    do
      case "$f" in
        *.sh)
          echo " [i] start $f";
          nohup "${f}" > /tmp/$(basename ${f} .sh).log 2>&1 &
          ;;
        *)
          echo " [w] ignoring $f"
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

  echo " ---------------------------------------------------"
  echo "   Icinga ${ICINGA_TYPE} Version ${ICINGA_VERSION} - build: ${BUILD_DATE}"
  echo " ---------------------------------------------------"
  echo ""

  . /init/common.sh

  prepare

  . /init/database/mysql.sh
  . /init/pki_setup.sh
  . /init/api_user.sh
  . /init/graphite_setup.sh
  . /init/configure_ssmtp.sh

  correct_rights

  custom_scripts

  echo " [i] start init process ..."

  /bin/s6-svscan /etc/s6
}


run

# EOF
