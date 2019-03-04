#!/bin/bash

# use inotify to detect changes in the ${monitored_directory} and sync
# changes to ${backup_directory}
# when a 'delete' event is triggerd, the file/directory will also removed
# from ${backup_directory}
#
# in this case, we need only a sync of all 'zones.*' files/directory
#

. /init/output.sh

monitored_directory="/var/lib/icinga2"
hostname_f=$(hostname -f)

log_info "start the api zone debugger"


grep -nrB2 "template Host" ${monitored_directory}/*

inotifywait \
  --monitor \
  --recursive \
  --event create \
  --event delete \
  --event attrib \
  --event close_write \
  --event moved_to \
  --event moved_from \
  ${monitored_directory} |
  while read path action file
  do
    [[ -z "${file}" ]] && continue
    #[[ ${path} =~ backup ]] && continue

    if [[ "${file}" == "current" ]] || [[ "${file}" == "_etc" ]] || [[ "${file}" == ".timestamp" ]]
    then
      continue
    fi

    if [[ "${DEBUG}" = "true" ]]
    then
      log_debug "api zone debugger - The file '$file' appeared in directory '$path' via '$action'"
    fi

  done
