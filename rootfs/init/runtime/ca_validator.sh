#!/bin/bash

# periodic check of the (satellite) CA file
# **this use the API from the icinga-cert-service!**
#
# when the CA file are not in  sync, we restart the container to
# getting a new certificate
#
# BE CAREFUL WITH THIS 'FEATURE'!
# IT'S JUST A FIX FOR A FAULTY USE.
#

. /init/output.sh

. /init/cert/certificate_handler.sh

while true
do

  . /init/wait_for/cert_service.sh

  validate_local_ca

  if [ ! -f ${ICINGA_CERT_DIR}/${HOSTNAME}.key ]
  then

    log_error "the validation of our CA was not successful."
    log_error "clean up and restart."
    log_error "headshot ..."

    icinga_pid=$(ps ax | grep icinga2 | grep -v grep | awk '{print $1}')

    [ -z "${icinga2_pid}" ] || killall icinga2 > /dev/null 2> /dev/null

    exit 1
  fi

  sleep 5m
done
