
# configure the Graphite Support
#

if ( [[ -z ${CARBON_HOST} ]] || [[ -z ${CARBON_PORT} ]] )
then
  log_info "no settings for graphite feature found"
  unset CARBON_HOST
  unset CARBON_PORT
  return
fi

configure_graphite() {

  enable_icinga_feature graphite

  config_file="/etc/icinga2/features-enabled/graphite.conf"

  # create (overwrite existing) configuration
  #
  if [[ -e "${config_file}" ]]
  then
    cat > "${config_file}" <<-EOF

object GraphiteWriter "graphite" {
  host = "${CARBON_HOST}"
  port = ${CARBON_PORT}
}

EOF
  fi
}

configure_graphite
