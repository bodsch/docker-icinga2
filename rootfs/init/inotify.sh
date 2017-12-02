#!/bin/sh

inotifywait \
  --monitor /etc/icinga2/automatic-zones.d \
  --event modify \
  --event close_write \
  --event delete |
  while read path action file; do
    echo "The file '$file' appeared in directory '$path' via '$action'"
    if [ "${action}" == "DELETE" ]
    then
      rm -f /var/lib/icinga2/backup/$(basename ${path})/${file}
    else
      cp -r ${path} /var/lib/icinga2/backup/
    fi
    # do something with the file
  done
