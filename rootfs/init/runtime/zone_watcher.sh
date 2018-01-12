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
  log_warn "headshot ..."

  icinga_pid=$(ps ax | grep icinga2 | grep -v grep | awk '{print $1}')
  [ -z "${icinga_pid}" ] || killall icinga2 > /dev/null 2> /dev/null
  kill -9 1
  exit 1
}

log_info "start the api zone monitor"

inotifywait \
  --monitor \
  --recursive \
  --event create \
  --event attrib \
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
    elif [[ "${action}" = "CREATE" ]]
    then
      if [[ $(basename ${path}) =~ ${hostname_f} ]]
      then
        log_info "the zone configuration for myself has changed."
        log_info "we must remove the old endpoint configuration from the static zones.conf"

        if [ $(grep -c "^object Endpoint" /etc/icinga2/zones.conf) -gt 0 ]
        then
          sed -i 's|^object Endpoint NodeName.*||' /etc/icinga2/zones.conf
        fi

        cp /etc/icinga2/zones.conf ${ICINGA_LIB_DIR}/backup/zones.conf

        touch /tmp/stage_3
      fi
    elif [[ "${action}" = "CREATE,ISDIR" ]]
    then
      if [[ ${path} =~ ${hostname_f} ]] && [[ "${file}" = ".timestamp" ]]
      then
        log_info "the zone configuration for myself has changed."
        log_info "we need an restart for reloading."

        if [ $(grep -c "^object Endpoint" /etc/icinga2/zones.conf) -gt 0 ]
        then
          sed -i 's|^object Endpoint NodeName.*||' /etc/icinga2/zones.conf
        fi

      fi
    fi
  done
