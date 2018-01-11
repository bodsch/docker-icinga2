#!/bin/bash

# use inotify to detect changes in the ${monitored_directory} and sync
# changes to ${backup_directory}
# when a 'delete' event is triggerd, the file/directory will also removed
# from ${backup_directory}
#
# in this case, we need only a sync of all 'zones.*' files/directory
#

. /init/output.sh

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

    if ( [[ -z "${file}" ]] || [[ ! ${file} =~ ^zones* ]] )
    then
      continue
    fi

    log_info "service zone monitor - The file '$file' appeared in directory '$path' via '$action'"
    if [ "${action}" = "DELETE" ]
    then
      rm -f ${backup_directory}/$(basename ${path})/${file}
    elif [ "${action}" = "DELETE,ISDIR" ]
    then
      rm -rf ${backup_directory}/${file}
    elif [[ "${action}" = "CLOSE_WRITE,CLOSE" ]]
    then
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
  done
