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

log_info "start the service zone monitor"

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

    [[ "${DEBUG}" = "true" ]] && log_debug "service zone monitor - The file '$file' appeared in directory '$path' via '$action'"

    # monitor DELETE
    #
    if [[ "${action}" = "DELETE" ]]
    then
      # remove file
      #
      rm -f ${backup_directory}/$(basename ${path})/${file}

    # monitor DELETE,ISDIR
    #
    elif [[ "${action}" = "DELETE,ISDIR" ]]
    then
      # remove directory
      #
      rm -rf ${backup_directory}/${file}
    fi
  done
