
# restore a old zone file for automatic generated satellites
#
restore_backup() {

  cp_opts="--archive --force --recursive"
  [[ "${DEBUG}" = "true" ]] && cp_opts="${cp_opts} --verbose"

  # backwards compatibility
  # in an older version, we create all zone config files in an seperate directory
  #
  [[ -d ${ICINGA2_LIB_DIRECTORY}/backup/automatic-zones.d ]] && mv ${ICINGA2_LIB_DIRECTORY}/backup/automatic-zones.d ${ICINGA2_LIB_DIRECTORY}/backup/zones.d

  if [[ -d ${ICINGA2_LIB_DIRECTORY}/backup ]]
  then
    log_info "restore backup"

    if [[ "${DEBUG}" = "true" ]]
    then
      if [[ -e ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf ]]
      then
        grep -nrB2 "object Endpoint" ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf
      fi

      if [[ -e ${ICINGA2_LIB_DIRECTORY}/backup/zones.d ]]
      then
        grep -nrB2 "object Endpoint" ${ICINGA2_LIB_DIRECTORY}/backup/zones.d/*
      fi
    fi

    if [[ -f ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf ]]
    then
      [[ "${DEBUG}" = "true" ]] && log_debug "  - zones.conf"
      cp ${cp_opts} ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf /etc/icinga2/zones.conf
    fi

    if [[ -d ${ICINGA2_LIB_DIRECTORY}/backup/zones.d ]]
    then
      cp ${cp_opts} ${ICINGA2_LIB_DIRECTORY}/backup/zones.d/* /etc/icinga2/zones.d/
    fi

    if [[ -f ${ICINGA2_LIB_DIRECTORY}/backup/conf.d/api-users.conf ]]
    then
      [[ "${DEBUG}" = "true" ]] && log_debug "  - api-users.conf"
      cp ${cp_opts} ${ICINGA2_LIB_DIRECTORY}/backup/conf.d/api-users.conf /etc/icinga2/conf.d/api-users.conf
    fi

  fi
}


# copy master specific configurations
#
copy_master_specific_configurations() {

#  if [[ -f /etc/icinga2/zones.conf ]] && [[ -f /etc/icinga2/zones.conf-docker ]]
#  then
#    cp ${cp_opts} /etc/icinga2/zones.conf-docker /etc/icinga2/zones.conf
#  fi

  if [[ -d /etc/icinga2/zones.d/global-templates ]]
  then
    [[ "${DEBUG}" = "true" ]] && log_debug "copy global-templates"

    if [[ -f /etc/icinga2/master.d/templates_services.conf ]]
    then
      [[ "${DEBUG}" = "true" ]] && log_debug "  - templates_services.conf"
      cp ${cp_opts} /etc/icinga2/master.d/templates_services.conf /etc/icinga2/zones.d/global-templates/
    fi

    if [[ -f /etc/icinga2/satellite.d/services.conf ]]
    then
      [[ "${DEBUG}" = "true" ]] && log_debug "  - services.conf"
      cp ${cp_opts} /etc/icinga2/satellite.d/services.conf        /etc/icinga2/zones.d/global-templates/
    fi
  fi

  if [[ -f /etc/icinga2/master.d/satellite_services.conf ]]
  then
    [[ "${DEBUG}" = "true" ]] && log_debug "copy master.d/satellite_services.conf"
    cp ${cp_opts} /etc/icinga2/master.d/satellite_services.conf /etc/icinga2/conf.d/
  fi

  if [[ -f /etc/icinga2/satellite.d/commands.conf ]]
  then
    [[ "${DEBUG}" = "true" ]] && log_debug "copy satellite.d/commands.conf"
    cp ${cp_opts} /etc/icinga2/satellite.d/commands.conf /etc/icinga2/conf.d/satellite_commands.conf
  fi
}


# configure a icinga2 master instance
#
configure_icinga2_master() {

  enable_icinga_feature api

  create_ca

  restore_backup

  copy_master_specific_configurations
}

configure_icinga2_master
