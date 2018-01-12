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

# restart_myself() {
#   log_warn "headshot ..."
#   icinga_pid=$(ps ax | grep icinga2 | grep -v grep | awk '{print $1}')
#   [ -z "${icinga_pid}" ] || killall icinga2 > /dev/null 2> /dev/null
#   kill -9 1
#   exit 1
# }

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

    log_info "=>> api zone monitor - The file '$file' appeared in directory '$path' via '$action'"

    if [[ "${action}" = "CLOSE_WRITE,CLOSE" ]]
    then
      if [[ ${file} =~ ${hostname_f}.crt ]]
      then
        log_info "our certificate are replicated."
        log_info "replace the static zone config (if needed)"

        sed -i 's|^object Zone ZoneName.*}$|object Zone ZoneName { endpoints = [ NodeName ]; parent = "master" }|g' /etc/icinga2/zones.conf
        cp /etc/icinga2/zones.conf ${ICINGA_LIB_DIR}/backup/zones.conf

#         log_info "now, we need an restart for certificate reloading."
#        cat /etc/icinga2/zones.conf
#         sleep 15s
        # kill_icinga
      fi
    elif [[ "${action}" = "CREATE,ISDIR" ]]
    then
      if [[ ${file} =~ ${hostname_f} ]]
      then
        log_info "the zone configuration for myself has changed."
        log_info "we must remove the old endpoint configuration from the static zones.conf"

        sed -i '/^object Endpoint NodeName.*/d' /etc/icinga2/zones.conf
        cp /etc/icinga2/zones.conf ${ICINGA_LIB_DIR}/backup/zones.conf

#        log_info "add or modify my own host object"
        touch /tmp/add_host
        log_info "now, we need an restart for certificate and zone reloading."

        exit 1
      fi
    fi

#    elif [[ "${action}" = "CREATE,ISDIR" ]]
#    then
#      if [[ ${path} =~ ${hostname_f} ]] && [[ "${file}" = ".timestamp" ]]
#      then
#        log_info "the zone configuration for myself has changed."
#        log_info "we need an restart for reloading."
#
#        if [ $(grep -c "^object Endpoint" /etc/icinga2/zones.conf) -gt 0 ]
#        then
#          sed -i 's|^object Endpoint NodeName.*||' /etc/icinga2/zones.conf
#        fi
#
#      fi
#    fi
  done
