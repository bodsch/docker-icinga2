#!/bin/bash

# use inotify to detect changes in the ${monitored_directory} and sync
# changes to ${backup_directory}
# when a 'delete' event is triggerd, the file/directory will also removed
# from ${backup_directory}
#
# in this case, we need only a sync of all 'zones.*' files/directory
#

. /init/output.sh

monitored_directory="/var/lib/icinga2/api"

set -x

inotifywait \
  --monitor \
  --recursive \
  --event create \
  --event attrib \
  --event close_write \
  ${monitored_directory} |
  while read path action file
  do
    log_info "The file '$file' appeared in directory '$path' via '$action'"

    if ( [[ -z "${file}" ]] || [[ ! ${file} =~ ^$(hostname -f).conf ]] )
    then
      continue
    fi

    log_info "The file '$file' appeared in directory '$path' via '$action'"
    if [ "${action}" = "DELETE" ]
    then
      rm -f ${backup_directory}/$(basename ${path})/${file}
    elif [ "${action}" = "DELETE,ISDIR" ]
    then
      rm -rf ${backup_directory}/${file}
    else
      sed -i 's|^object Endpoint NodeName.*||' /etc/icinga2/zones.conf
    fi
  done
