
if ( [ -z ${CARBON_HOST} ] || [ -z ${CARBON_PORT} ] )
then
  echo " [i] no Settings for Graphite Feature found"

  return
fi

configureGraphite() {

  if [ $(icinga2 feature list | grep Enabled | grep -c graphite) -eq 0 ]
  then
    /usr/sbin/icinga2 feature enable graphite
  fi

  if [ -e /etc/icinga2/features-enabled/graphite.conf ]
  then
    sed -i \
      -e "s|^.*\ //host\ =\ .*|  host\ =\ \"${CARBON_HOST}\"|g" \
      -e "s|^.*\ //port\ =\ .*|  port\ =\ \"${CARBON_PORT}\"|g" \
      /etc/icinga2/features-enabled/graphite.conf
  fi
}

configureGraphite
