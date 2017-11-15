#!/bin/sh
#
#

if [ ${DEBUG} ]
then
  set -x
fi

export WORK_DIR=/srv/icinga2
export ICINGA_SATELLITE=false

HOSTNAME=$(hostname -f)

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
