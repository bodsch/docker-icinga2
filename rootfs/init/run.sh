#!/bin/sh
#
#

if [ ${DEBUG} ]
then
  set -x
fi

export WORK_DIR=/srv/icinga2

HOSTNAME=$(hostname -f)

# -------------------------------------------------------------------------------------------------

run() {

  . /init/common.sh

  prepare

  . /init/database/mysql.sh
  . /init/pki_setup.sh
  . /init/api_user.sh
  . /init/graphite_setup.sh
  . /init/configure_ssmtp.sh

  correctRights

  /bin/s6-svscan /etc/s6
}


run

# EOF
