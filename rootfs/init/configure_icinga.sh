#

# ICINGA2_MASTER must be an FQDN or an IP

# -------------------------------------------------------------------------------------------------

# create API config file
# this is needed for all instance types (master, satellite or agent)
#
create_api_config() {

  [[ -f /etc/icinga2/features-available/api.conf ]] || touch /etc/icinga2/features-available/api.conf

  # create api config
  #
  cat << EOF > /etc/icinga2/features-available/api.conf

object ApiListener "api" {
  accept_config = true
  accept_commands = true
  ticket_salt = TicketSalt
EOF

  # version 2.8 has some changes for certifiacte configuration
  #
  if [[ "${ICINGA2_MAJOR_VERSION}" = "2.7" ]]
  then
    cat << EOF >> /etc/icinga2/features-available/api.conf
  # look at https://www.icinga.com/docs/icinga2/latest/doc/16-upgrading-icinga-2/#upgrading-to-v28
  cert_path = SysconfDir + "/icinga2/pki/" + NodeName + ".crt"
  key_path  = SysconfDir + "/icinga2/pki/" + NodeName + ".key"
  ca_path   = SysconfDir + "/icinga2/pki/ca.crt"
}
EOF
  # < version 2.8, we must add the path to the certificate
  #
  else
    cat << EOF >> /etc/icinga2/features-available/api.conf
}
EOF
  fi
}


# ----------------------------------------------------------------------

. /init/cert/certificate_handler.sh

create_api_config

if [[ "${ICINGA2_TYPE}" = "Master" ]]
then
  # configure_icinga2_master
  . /init/icinga_types/master.sh
elif [[ "${ICINGA2_TYPE}" = "Satellite" ]]
then
  # configure_icinga2_satellite
  . /init/icinga_types/satellite.sh
else
  # configure_icinga2_agent
  . /init/icinga_types/agent.sh
fi
