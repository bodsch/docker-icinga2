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

attrib="false"

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
    [[ -z "${file}" ]] && continue
    [[ ${path} =~ backup ]] && continue

    if [[ "${file}" == "current" ]] || [[ "${file}" == "_etc" ]] || [[ "${file}" == ".timestamp" ]]
    then
      continue
    fi

    [[ "${DEBUG}" = "true" ]] && log_debug "api zone monitor - The file '$file' appeared in directory '$path' via '$action'"

    if [[ "${action}" = "ATTRIB" ]]
    then
      attrib="true"
    fi

#    if [[ "${DEBUG}" = "true" ]]
#    then
#      log_debug "api zone monitor - attrib: '${attrib}'"
#      log_debug "api zone monitor - action: '${action}'"
#    fi

    # monitor CLOSE_WRITE,CLOSE
    #
    if [[ "${attrib}" = "true" ]] && [[ "${action}" = "CLOSE_WRITE,CLOSE" ]]
    then
      ## only for the ${HOSTNAME}.crt
      ##
      #if [[ ${file} =~ ${hostname_f}.crt ]]
      #then
      #  log_info "our certificate are replicated."
      #  log_info "replace the static zone config (if needed)"
      #
      #  sed -i \
      #    -e 's|^object Zone ZoneName.*}$|object Zone ZoneName { endpoints = [ NodeName ]; parent = "master" }|g' \
      #    /etc/icinga2/zones.conf
      #
      #  cp /etc/icinga2/zones.conf ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf
      #fi

      attrib="false"

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
          -e "s/^\(object\ Endpoint\ NodeName .*\)/\/\/ \1/" \
          /etc/icinga2/zones.conf

        cp /etc/icinga2/zones.conf ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf

        if [[ -d /etc/icinga2/zones.d/global-templates ]]
        then
          log_info "we remove also the static global-templates directory"
          rm -rf /etc/icinga2/zones.d/global-templates
        fi

        if [[ -d /etc/icinga2/zones.d/director-global ]]
        then
          log_info "we remove also the static director-global directory"
          rm -rf /etc/icinga2/zones.d/director-global
        fi

        # touch file for later add the satellite to the master over API
        #
        touch /tmp/add_host

        log_INFO "now, we restart ourself for certificate and zone reloading."

        # kill myself to finalize
        #
        pid=$(ps ax -o pid,args  | grep -v grep | grep icinga2 | grep daemon | awk '{print $1}')
        if [[ $(echo -e "${pid}" | wc -w) -gt 0 ]]
        then
          [[ "${DEBUG}" = "true" ]] && log_debug " killall --verbose --signal HUP icinga2"
          killall --verbose --signal HUP icinga2 > /dev/null 2> /dev/null
        fi
      fi

      attrib="false"
    fi
  done
