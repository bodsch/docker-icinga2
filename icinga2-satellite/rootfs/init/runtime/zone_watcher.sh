#!/bin/bash

# use inotify to detect changes in the ${monitored_directory} and sync
# changes to ${backup_directory}
# when a 'delete' event is triggerd, the file/directory will also removed
# from ${backup_directory}
#
# in this case, we need only a sync of all 'zones.*' files/directory
#

#if [[ ! -z ${DEBUG+x} ]]
#then
#  if [[ "${DEBUG}" = "true" ]] || [[ ${DEBUG} -eq 1 ]]
#  then
#    set -x
#  fi
#fi

env | grep DEBUG

. /init/output.sh
. /init/runtime/service_handler.sh

monitored_directory="/var/lib/icinga2"
hostname_f=$(hostname -f)

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
    if [[ ! -z ${DEBUG+x} ]] && [[ "${DEBUG}" = "true" ]] || [[ ${DEBUG} -eq 1 ]]
    then
      log_debug "api zone monitor - The file '$file' appeared in directory '$path' via '$action'"
    fi

    [[ -z "${file}" ]] && continue

    log_info "api zone monitor - The file '$file' appeared in directory '$path' via '$action'"

    # monitor CLOSE_WRITE,CLOSE
    #
    if [[ "${action}" = "CLOSE_WRITE,CLOSE" ]]
    then
      # only for the ${HOSTNAME}.crt
      #
      if [[ ${file} =~ sign_${hostname_f}.json ]]
      then
        if [[ ! -z ${DEBUG+x} ]] && [[ "${DEBUG}" = "true" ]] || [[ ${DEBUG} -eq 1 ]]
        then
          ls -1 ${monitored_directory}/*
        fi

        log_info "our certificate are replicated."
        log_info "replace the static zone config (if needed)"

        sed -i \
          -e 's|^object Zone ZoneName.*}$|object Zone ZoneName { endpoints = [ NodeName ]; parent = "master" }|g' \
          /etc/icinga2/zones.conf

        cp /etc/icinga2/zones.conf ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf
      fi
    # monitor CREATE,ISDIR
    #
    elif [[ "${action}" = "CREATE,ISDIR" ]]
    then
      # only if the directory is equal to the ${HOSTNAME}
      #
      if [[ ${file} =~ ${hostname_f} ]]
      then
        log_info "the zone configuration for myself has changed."
        log_info "we must remove the old endpoint configuration from the static zones.conf"

        sed -i \
          -e '/^object Endpoint NodeName.*/d' \
          /etc/icinga2/zones.conf

        cp /etc/icinga2/zones.conf ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf

        log_info "we remove also the static global-templates directory"
        [[ -d /etc/icinga2/zones.d/global-templates ]] && rm -rf /etc/icinga2/zones.d/global-templates

        log_info "we remove also the static director-global directory"
        [[ -d /etc/icinga2/zones.d/director-global ]] && rm -rf /etc/icinga2/zones.d/director-global

        # touch file for later add the satellite to the master over API
        #
        touch /tmp/add_host
        log_info "now, we need an restart for certificate and zone reloading."

        # kill myself to finalize
        #
        killall icinga2
        exit 1
      fi
    fi
  done
