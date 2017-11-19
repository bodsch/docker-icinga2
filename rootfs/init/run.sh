#!/bin/sh
#
#

[ ${DEBUG} ] && set -x

HOSTNAME=$(hostname -f)

ICINGA_CERT_DIR="/etc/icinga2/pki"
ICINGA_VERSION=$(icinga2 --version | head -n1 | awk -F 'version: ' '{printf $2}' | awk -F \. {'print $1 "." $2'} | sed 's|r||')
[ "${ICINGA_VERSION}" = "2.8" ] && ICINGA_CERT_DIR="/var/lib/icinga2/certs"

export WORK_DIR=/srv/icinga2
export ICINGA_SATELLITE=false
export ICINGA_VERSION
export ICINGA_CERT_DIR
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


run() {

  echo " ---------------------------------------------------"
  echo "   Icinga ${ICINGA_VERSION} build: ${BUILD_DATE}"
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

  /bin/s6-svscan /etc/s6
}


run

# EOF
