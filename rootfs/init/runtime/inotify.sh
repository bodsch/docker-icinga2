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

    if ( [[ -z "${file}" ]] || [[ ! ${file} =~ ^zones* ]] && [[ "${file}" != "api-users.conf" ]] )
    then
      continue
    fi

    log_info "service zone monitor - The file '$file' appeared in directory '$path' via '$action'"

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

    # monitor CLOSE_WRITE,CLOSE
    #
    elif [[ "${action}" = "CLOSE_WRITE,CLOSE" ]]
    then
      # use rsync for an backup
      # we need only zones.conf and the complete zones.d directory
      # all others are irrelevant
      #
      rsync \
        --archive \
        --recursive \
        --delete \
        --verbose \
        --include="zones.d/***" \
        --include="zones.*" \
        --include="conf.d" \
        --include="conf.d/api-users.conf" \
        --exclude='*' \
        ${monitored_directory}/* ${backup_directory}/
    fi
  done
