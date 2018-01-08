#!/bin/sh

monitored_directory="/etc/icinga2/zones.d"
backup_directory="/var/lib/icinga2/backup/zones.d"

inotifywait \
  --monitor ${monitored_directory} \
  --recursive \
  --event close_write \
  --event delete |
  while read path action file
  do
    echo " [i] The file '$file' appeared in directory '$path' via '$action'"
    if [ "${action}" = "DELETE" ]
    then
      rm -f ${backup_directory}/$(basename ${path})/${file}
    elif [ "${action}" = "DELETE,ISDIR" ]
    then
      rm -rf ${backup_directory}/${file}
    else
      cp -r ${monitored_directory}/$(basename ${path}) ${backup_directory}/
    fi
    echo ""
  done
