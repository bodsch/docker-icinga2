
# restore a old zone file for automatic generated satellites
#
restore_backup() {

  # backwards compatibility
  # in an older version, we create all zone config files in an seperate directory
  #
  [[ -d ${ICINGA2_LIB_DIRECTORY}/backup/automatic-zones.d ]] && mv ${ICINGA2_LIB_DIRECTORY}/backup/automatic-zones.d ${ICINGA2_LIB_DIRECTORY}/backup/zones.d

  if [[ -d ${ICINGA2_LIB_DIRECTORY}/backup ]]
  then
    log_info "restore backup"

    [[ -f ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf ]] && cp -a ${ICINGA2_LIB_DIRECTORY}/backup/zones.conf /etc/icinga2/zones.conf
    [[ -d ${ICINGA2_LIB_DIRECTORY}/backup/zones.d ]]    && cp -ar ${ICINGA2_LIB_DIRECTORY}/backup/zones.d/* /etc/icinga2/zones.d/
    [[ -f ${ICINGA2_LIB_DIRECTORY}/backup/conf.d/api-users.conf ]] && cp -a ${ICINGA2_LIB_DIRECTORY}/backup/conf.d/api-users.conf /etc/icinga2/conf.d/api-users.conf
  fi
}


# configure a icinga2 master instance
#
configure_icinga2_master() {

  enable_icinga_feature api

  create_ca

  restore_backup

  # copy master specific configurations
  #
  if [[ -d /etc/icinga2/zones.d/global-templates ]]
  then
    [[ -f /etc/icinga2/master.d/templates_services.conf ]] && cp /etc/icinga2/master.d/templates_services.conf /etc/icinga2/zones.d/global-templates/
  fi

  [[ -f /etc/icinga2/master.d/satellite_services.conf ]] && cp /etc/icinga2/master.d/satellite_services.conf /etc/icinga2/conf.d/
  [[ -f /etc/icinga2/satellite.d/commands.conf ]] && cp /etc/icinga2/satellite.d/commands.conf /etc/icinga2/conf.d/satellite_commands.conf
}

configure_icinga2_master
