#!/bin/sh

inotifywait \
  --monitor /etc/icinga2/automatic-zones.d \
  --event modify \
  --event close_write \
  --event delete |
  while read path action file; do
    echo "The file '$file' appeared in directory '$path' via '$action'"
    cp -rv ${path} ${WORK_DIR}/
    # do something with the file
  done
