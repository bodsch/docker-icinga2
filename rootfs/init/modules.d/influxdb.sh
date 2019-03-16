
# configure the InfluxDB Support
#

if ( [[ -z ${INFLUXDB_HOST} ]] || [[ -z ${INFLUXDB_PORT} ]] )
then
  log_info "no settings for influxdb feature found"
  unset INFLUXDB_HOST
  unset INFLUXDB_PORT
  return
fi

configure_influxdb() {

  enable_icinga_feature influxdb

  config_file="/etc/icinga2/features-enabled/influxdb.conf"

  # create (overwrite existing) configuration
  #
  if [[ -e "${config_file}" ]]
  then
    cat > "${config_file}" <<-EOF

object InfluxdbWriter "influxdb" {
  host            = "${INFLUXDB_HOST}"
  port            = ${INFLUXDB_PORT}
  database        = "${INFLUXDB_DB}"
  username        = "${INFLUXDB_USER}"
  password        = "${INFLUXDB_PASS}"
  flush_threshold = 1024
  flush_interval  = 10s

  host_template = {
    measurement = "\$host.check_command$"
    tags = {
      hostname = "\$host.name$"
    }
  }
  service_template = {
    measurement = "\$service.check_command$"
    tags = {
      hostname = "\$host.name$"
      service = "\$service.name$"
    }
  }
}

EOF

  fi
}

configure_influxdb
