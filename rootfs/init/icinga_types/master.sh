
# restore a old zone file for automatic generated satellites
#
restore_old_zone_config() {

  # backwards compatibility
  # in an older version, we create all zone config files in an seperate directory
  #
  if [ -d ${ICINGA_LIB_DIR}/backup/automatic-zones.d ]
  then
    mv ${ICINGA_LIB_DIR}/backup/automatic-zones.d ${ICINGA_LIB_DIR}/backup/zones.d
  fi

  if [ -d ${ICINGA_LIB_DIR}/backup/zones.d ]
  then
    log_info "restore older zone configurations"

    rsync \
      --archive \
      --recursive \
      --delete \
      --include="zones.d/***" \
      --include="zones.*" \
      --exclude='*' \
      ${ICINGA_LIB_DIR}/backup/* /etc/icinga2/
  fi

}


# configure a icinga2 master instance
#
configure_icinga2_master() {

#  log_info "we are the master .."

  enable_icinga_feature api

  create_ca

  restore_old_zone_config

  # copy master specific configurations
  #
  ( [ -d /etc/icinga2/zones.d/global-templates ] && [ -f /etc/icinga2/master.d/templates_services.conf ] ) && cp /etc/icinga2/master.d/templates_services.conf /etc/icinga2/zones.d/global-templates/
  [ -f /etc/icinga2/master.d/satellite_services.conf ] && cp /etc/icinga2/master.d/satellite_services.conf /etc/icinga2/conf.d/
  [ -f /etc/icinga2/satellite.d/commands.conf ] && cp /etc/icinga2/satellite.d/commands.conf /etc/icinga2/conf.d/satellite_commands.conf
}

configure_icinga2_master
