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

restart_myself() {
  touch /tmp/stage_3
  log_error "headshot ..."
  ps ax
  icinga_pid=$(ps ax | grep icinga2 | grep -v grep | awk '{print $1}')
  [ -z "${icinga_pid}" ] || killall icinga2 > /dev/null 2> /dev/null
  kill -9 1
  exit 1
}


inotifywait \
  --monitor \
  --recursive \
  --event close_write \
  ${monitored_directory} |
  while read path action file
  do
    #log_info "The file '$file' appeared in directory '$path' via '$action'"

    if [[ -z "${file}" ]]
    then
      continue
    fi

    log_info "api zone monitor - The file '$file' appeared in directory '$path' via '$action'"

    if [[ "${action}" = "CLOSE_WRITE,CLOSE" ]]
    then
      if [[ ${file} =~ .crt ]]
      then
        log_info "the master certs are replicated."
        log_info "we need an restart for reloading."
        sleep 15s
        restart_myself
      fi
    fi
  done
