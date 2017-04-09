#
# Script to Configure the Graphite Support


if ( [ -z ${CARBON_HOST} ] || [ -z ${CARBON_PORT} ] )
then
  echo " [i] no Settings for Graphite Feature found"

  return
fi

configureGraphite() {

  enableIcingaFeature graphite

  if [ -e /etc/icinga2/features-enabled/graphite.conf ]
  then
    sed -i \
      -e "s|^.*\ //host\ =\ .*|  host\ =\ \"${CARBON_HOST}\"|g" \
      -e "s|^.*\ //port\ =\ .*|  port\ =\ \"${CARBON_PORT}\"|g" \
      /etc/icinga2/features-enabled/graphite.conf
  fi
}

configureGraphite
