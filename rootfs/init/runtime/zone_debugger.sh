#!/bin/bash

# use inotify to detect changes in the ${monitored_directory} and sync
# changes to ${backup_directory}
# when a 'delete' event is triggerd, the file/directory will also removed
# from ${backup_directory}
#
# in this case, we need only a sync of all 'zones.*' files/directory
#

. /init/output.sh
. /init/runtime/service_handler.sh

monitored_directory="/var/lib/icinga2"
hostname_f=$(hostname -f)

log_info "start the api zone debugger"

inotifywait \
  --monitor \
  --recursive \
  --event create \
  --event attrib \
  --event close_write \
  ${monitored_directory} |
  while read path action file
  do
    [[ -z "${file}" ]] && continue
    [[ ${path} =~ backup ]] && continue

    if [[ "${file}" == "current" ]] || [[ "${file}" == "_etc" ]] || [[ "${file}" == ".timestamp" ]]
    then
      continue
    fi

    [[ "${DEBUG}" = "true" ]] && log_debug "api zone debugger - The file '$file' appeared in directory '$path' via '$action'"


  done
