
# restore a old zone file for automatic generated satellites
#
restore_backup() {

  # backwards compatibility
  # in an older version, we create all zone config files in an seperate directory
  #
  [[ -d ${ICINGA_LIB_DIR}/backup/automatic-zones.d ]] && mv ${ICINGA_LIB_DIR}/backup/automatic-zones.d ${ICINGA_LIB_DIR}/backup/zones.d

  if [[ -d ${ICINGA_LIB_DIR}/backup ]]
  then
    log_info "restore backup"

    [[ -f ${ICINGA_LIB_DIR}/backup/zones.conf ]] && cp -a ${ICINGA_LIB_DIR}/backup/zones.conf /etc/icinga2/zones.conf
    [[ -d ${ICINGA_LIB_DIR}/backup/zones.d ]]    && cp -ar ${ICINGA_LIB_DIR}/backup/zones.d/* /etc/icinga2/zones.d/
    [[ -f ${ICINGA_LIB_DIR}/backup/conf.d/api-users.conf ]] && cp -a ${ICINGA_LIB_DIR}/backup/conf.d/api-users.conf /etc/icinga2/conf.d/api-users.conf
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
  ( [[ -d /etc/icinga2/zones.d/global-templates ]] && [[ -f /etc/icinga2/master.d/templates_services.conf ]] ) && cp /etc/icinga2/master.d/templates_services.conf /etc/icinga2/zones.d/global-templates/
  [[ -f /etc/icinga2/master.d/satellite_services.conf ]] && cp /etc/icinga2/master.d/satellite_services.conf /etc/icinga2/conf.d/
  [[ -f /etc/icinga2/satellite.d/commands.conf ]] && cp /etc/icinga2/satellite.d/commands.conf /etc/icinga2/conf.d/satellite_commands.conf
}

configure_icinga2_master
