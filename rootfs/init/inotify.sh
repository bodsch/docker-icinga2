#!/bin/bash

monitored_directory="/etc/icinga2"
backup_directory="/var/lib/icinga2/backup"

inotifywait \
  --monitor \
  --recursive \
  --event create \
  --event attrib \
  --event close_write \
  --event delete \
  ${monitored_directory} |
  while read path action file
  do
    echo -n " [i] The file '$file' appeared in directory '$path' via '$action'"

    if ( [[ -z "${file}" ]] || [[ ! ${file} =~ ^zones* ]] )
    then
      echo " CONTINUE"
      continue
    fi

    echo " DOING"

    echo " [i] The file '$file' appeared in directory '$path' via '$action'"
    if [ "${action}" = "DELETE" ]
    then
      rm -f ${backup_directory}/$(basename ${path})/${file}
    elif [ "${action}" = "DELETE,ISDIR" ]
    then
      rm -rf ${backup_directory}/${file}
    else
      # cp -r ${monitored_directory}/$(basename ${path}) ${backup_directory}/
      rsync \
        --archive \
        --recursive \
        --delete \
        --include="zones.d/***" \
        --include="zones.*" \
        --exclude='*' \
        ${monitored_directory}/* ${backup_directory}/
    fi
#    echo ""
  done
