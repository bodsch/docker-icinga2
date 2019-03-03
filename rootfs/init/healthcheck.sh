#!/bin/bash

pid=$(ps ax -o pid,args  | grep -v grep | grep icinga2 | grep daemon | awk '{print $1}')

if [[ $(echo -e "${pid}" | wc -w) -gt 0 ]]
then
  # test the configuration
  #
  /usr/sbin/icinga2 \
    daemon \
    --log-level critical \
    --validate

  # validation are not successful
  #
  if [[ $? -gt 0 ]]
  then
    echo "the validation of our configuration was not successful."
    exit 1
  fi

  exit 0
fi

exit 2
