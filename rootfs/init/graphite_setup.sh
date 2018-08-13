
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

  if [[ -e /etc/icinga2/features-enabled/graphite.conf ]]
  then
    sed -i \
      -e "s|^.*\ //host\ =\ .*|  host\ =\ \"${CARBON_HOST}\"|g" \
      -e "s|^.*\ //port\ =\ .*|  port\ =\ \"${CARBON_PORT}\"|g" \
      /etc/icinga2/features-enabled/graphite.conf
  fi
}

configure_graphite
