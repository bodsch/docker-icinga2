#

#USE_CERT_SERVICE=${USE_CERT_SERVICE:-false}
#export CERT_SERVICE_BA_USER=${CERT_SERVICE_BA_USER:-"admin"}
#export CERT_SERVICE_BA_PASSWORD=${CERT_SERVICE_BA_PASSWORD:-"admin"}
#export CERT_SERVICE_API_USER=${CERT_SERVICE_API_USER:-""}
#export CERT_SERVICE_API_PASSWORD=${CERT_SERVICE_API_PASSWORD:-""}
#export CERT_SERVICE_SERVER=${CERT_SERVICE_SERVER:-"localhost"}
#export CERT_SERVICE_PORT=${CERT_SERVICE_PORT:-"80"}
#export CERT_SERVICE_PATH=${CERT_SERVICE_PATH:-"/"}
#
#export PKI_CMD="icinga2 pki"
#export PKI_KEY_FILE="${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key"
#export PKI_CSR_FILE="${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.csr"
#export PKI_CRT_FILE="${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt"

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
  if [[ "${ICINGA2_MAJOR_VERSION}" == "2.8" ]]
  then
    # look at https://www.icinga.com/docs/icinga2/latest/doc/16-upgrading-icinga-2/#upgrading-to-v28
    cat << EOF >> /etc/icinga2/features-available/api.conf
}
EOF
  # < version 2.8, we must add the path to the certificate
  #
  else

    cat << EOF >> /etc/icinga2/features-available/api.conf
  cert_path = SysconfDir + "/icinga2/pki/" + NodeName + ".crt"
  key_path = SysconfDir + "/icinga2/pki/" + NodeName + ".key"
  ca_path = SysconfDir + "/icinga2/pki/ca.crt"
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
