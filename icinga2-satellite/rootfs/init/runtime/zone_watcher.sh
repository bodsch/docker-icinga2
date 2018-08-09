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

log_info "start the api zone monitor for '${hostname_f}'"

inotifywait \
  --monitor \
  --recursive \
  --event create \
  --event attrib \
  --event close_write \
  ${monitored_directory} |
  while read path action file
  do

    if [[ -z "${file}" ]] || [[ "${file}" = "current" ]]
    then
      continue
    fi


    if [[ ${file} =~ ${hostname_f} ]] || [[ ${file} =~ ^ca.crt$ ]]
    then
      # log_debug "api zone monitor - The file '$file' appeared in directory '$path' via '$action'"

      #
      #
      #
      if [[ "${action}" = "CREATE,ISDIR" ]] && [[ ${file} =~ ${hostname_f} ]]
      then
        log_info "api zone monitor - the zone configuration for myself has changed"
        log_info "api zone monitor - we must remove the old endpoint configuration from the static zones.conf"

        sed -i \
          -e '/^object Endpoint NodeName.*/d' \
          /etc/icinga2/zones.conf

        cp /etc/icinga2/zones.conf ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf

        log_info "api zone monitor - we remove also the static global-templates directory"
        [[ -d /etc/icinga2/zones.d/global-templates ]] && rm -rf /etc/icinga2/zones.d/global-templates

        log_info "api zone monitor - we remove also the static director-global directory"
        [[ -d /etc/icinga2/zones.d/director-global ]] && rm -rf /etc/icinga2/zones.d/director-global

        # touch file for later add the satellite to the master over API
        #
        touch /tmp/add_host
        log_info "api zone monitor - now, we need an restart for certificate and zone reloading"

        # kill myself to finalize
        #
        icinga_pid=$(ps ax | grep icinga2 | grep daemon | grep -v grep | awk '{print $1}')
        [[ -z "${icinga2_pid}" ]] || killall icinga2 > /dev/null 2> /dev/null
        # killall icinga2
        exit 1
      fi

      #
      #
      #
      if [[ "${action}" = "CLOSE_WRITE,CLOSE" ]] && ( [[ ${file} =~ ^${hostname_f}.crt$ ]] || [[ ${file} =~ ^ca.crt$ ]] )
      then

        if [[ -f ${monitored_directory}/certs/${hostname_f}.crt ]] && [[ -f ${monitored_directory}/certs/ca.crt ]]
        then
          log_info "api zone monitor - our certificate are replicated"
          log_info "api zone monitor - replace the static zone config (if needed)"

          sed -i \
            -e 's|^object Zone ZoneName.*}$|object Zone ZoneName { endpoints = [ NodeName ]; parent = "master" }|g' \
            /etc/icinga2/zones.conf

          cp /etc/icinga2/zones.conf ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf
        fi
      fi

    fi

  done
