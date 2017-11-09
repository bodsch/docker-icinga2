#!/bin/sh

ICINGA_CERT_SERVICE=${ICINGA_CERT_SERVICE:-false}
ICINGA_CERT_SERVICE_BA_USER=${ICINGA_CERT_SERVICE_BA_USER:-"admin"}
ICINGA_CERT_SERVICE_BA_PASSWORD=${ICINGA_CERT_SERVICE_BA_PASSWORD:-"admin"}
ICINGA_CERT_SERVICE_API_USER=${ICINGA_CERT_SERVICE_API_USER:-""}
ICINGA_CERT_SERVICE_API_PASSWORD=${ICINGA_CERT_SERVICE_API_PASSWORD:-""}
ICINGA_CERT_SERVICE_SERVER=${ICINGA_CERT_SERVICE_SERVER:-"localhost"}
ICINGA_CERT_SERVICE_PORT=${ICINGA_CERT_SERVICE_PORT:-"80"}
ICINGA_CERT_SERVICE_PATH=${ICINGA_CERT_SERVICE_PATH:-"/"}

# ICINGA_MASTER must be an FQDN or an IP

# -------------------------------------------------------------------------------------------------

if [ ! ${ICINGA_CLUSTER} ]
then
  echo " [i] we need no cluster config .."

  return
fi

# get a new icinga certificate from our icinga-master
#
#
get_certificate() {

  validate_local_ca

  if [ -f /etc/icinga2/pki/${HOSTNAME}.key ]
  then
    return
  fi

  if [ ${ICINGA_CERT_SERVICE} ]
  then
    echo ""
    echo " [i] we ask our cert-service for a certificate .."

    # generate a certificate request
    #
    code=$(curl \
      --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --request GET \
      --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
      --header "X-API-KEY: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
      --write-out "%{http_code}\n" \
      --output /tmp/request_${HOSTNAME}.json \
      http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/request/${HOSTNAME})

    if ( [ $? -eq 0 ] && [ ${code} -eq 200 ] )
    then

      echo " [i] certifiacte request was successful"
      echo " [i] download and install the certificate"

      master_name=$(jq --raw-output .master_name /tmp/request_${HOSTNAME}.json)
      checksum=$(jq --raw-output .checksum /tmp/request_${HOSTNAME}.json)

#      rm -f /tmp/request_${HOSTNAME}.json

      mkdir -p ${WORK_DIR}/pki/${HOSTNAME}

      # get our created cert
      #
      code=$(curl \
        --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
        --silent \
        --request GET \
        --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
        --header "X-API-KEY: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
        --header "X-CHECKSUM: ${checksum}" \
        --write-out "%{http_code}\n" \
        --request GET \
        --output ${WORK_DIR}/pki/${HOSTNAME}/${HOSTNAME}.tgz \
        http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/cert/${HOSTNAME})

      if ( [ $? -eq 0 ] && [ ${code} -eq 200 ] )
      then

        cd ${WORK_DIR}/pki/${HOSTNAME}

        # the download has not working
        #
        if [ ! -f ${HOSTNAME}.tgz ]
        then
          echo " [E] Cert File '${HOSTNAME}.tgz' not found!"
          exit 1
        fi

        tar -xzf ${HOSTNAME}.tgz

        if [ ! -f ${HOSTNAME}.pem ]
        then
          cat ${HOSTNAME}.crt ${HOSTNAME}.key >> ${HOSTNAME}.pem
        fi

        # store the master for later restart
        #
        echo "${master_name}" > ${WORK_DIR}/pki/${HOSTNAME}/master

        create_api_config

      else
        echo " [E] can't download out certificate!"

        rm -rf ${WORK_DIR}/pki 2> /dev/null

        unset ICINGA_API_PKI_PATH
      fi
    else

      error=$(cat /tmp/request_${HOSTNAME}.json)

      echo " [E] ${code} - the cert-service tell us a problem: '${error}'"
      echo " [E] exit ..."

      rm -f /tmp/request_${HOSTNAME}.json
      exit 1
    fi
  fi
}

# validate our lokal certificate against our certificate service
# with an API Request against
# http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/validate/${checksum})
#
# if this failed, the PKI schould be removed
#
validate_local_ca() {

  if [ -f ${WORK_DIR}/pki/${HOSTNAME}/ca.crt ]
  then
    checksum=$(sha256sum ${WORK_DIR}/pki/${HOSTNAME}/ca.crt | cut -f 1 -d ' ')

    # validate our ca file
    #
    code=$(curl \
      --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --request GET \
      --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
      --header "X-API-KEY: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
      --write-out "%{http_code}\n" \
      --output /tmp/validate_ca_${HOSTNAME}.json \
      http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/validate/${checksum})

    if ( [ $? -eq 0 ] && [ ${code} == 200 ] )
    then
      rm -f /tmp/validate_ca_${HOSTNAME}.json
    else

      status=$(echo "${code}" | jq --raw-output .status 2> /dev/null)
      message=$(echo "${code}" | jq --raw-output .message 2> /dev/null)

      echo " [w] our master has a new CA"

      rm -f /tmp/validate_ca_${HOSTNAME}.json
      rm -rf ${WORK_DIR}/pki
      rm -rf /etc/icinga2/pki/*

      cat /dev/null > /etc/icinga2/features-available/api.conf
      #touch /etc/icinga2/features-available/api.conf
    fi
  else
    # we have no local cert file ..
    :
  fi
}

# validate our lokal certificate against our icinga-master
# with an API Request against https://${ICINGA_HOST}:${ICINGA_API_PORT}/v1/status/CIB
#
# if this failed, the PKI schould be removed
#
validate_cert() {

  if [ -d ${WORK_DIR}/pki/${HOSTNAME} ]
  then
    cd ${WORK_DIR}/pki/${HOSTNAME}

    if [ ! -f ${HOSTNAME}.pem ]
    then
      cat ${HOSTNAME}.crt ${HOSTNAME}.key >> ${HOSTNAME}.pem
    fi

    echo " [i] validate our certifiacte"

    code=$(curl \
      --silent \
      --insecure \
      --user ${ICINGA_CERT_SERVICE_API_USER}:${ICINGA_CERT_SERVICE_API_PASSWORD} \
      --capath . \
      --cert ./dashing.pem \
      --cacert ./ca.crt \
      https://${ICINGA_HOST}:${ICINGA_API_PORT}/v1/status/CIB)

    if [[ $? -gt 0 ]]
    then
      rm -rf ${WORK_DIR}/pki
    fi
  fi
}


# configure a icinga2 master instance
#
configure_icinga2_master() {

  echo " [i] we are the master .."

  # icinga2 cert - restore CA
  if [ -d /var/lib/icinga2/ca ]
  then
    echo " [i] create new CA"
  else
    if ( [ -d ${WORK_DIR}/pki ] && [ -d ${WORK_DIR}/ca ] )
    then
      echo " [i] restore older CA"

      cp -arv ${WORK_DIR}/ca               /var/lib/icinga2/ 2> /dev/null
    else
      echo " [i] create new CA"

      rm -f ${WORK_DIR}/pki/${HOSTNAME}*  2> /dev/null
      rm -f ${WORK_DIR}/pki/ca.crt        2> /dev/null

      rm -f /etc/icinga2/pki/${HOSTNAME}* 2> /dev/null
    fi
  fi

  # set NodeName
  sed -i "s,^.*\ NodeName\ \=\ .*,const\ NodeName\ \=\ \"${HOSTNAME}\",g" /etc/icinga2/constants.conf

  # icinga2 API cert - regenerate new private key and certificate when running in a new container
  if [ ! -f /etc/icinga2/pki/${HOSTNAME}.key ]
  then
    echo " [i] create new certificate"

    [ -d ${WORK_DIR}/pki ] || mkdir ${WORK_DIR}/pki

    PKI_CMD="icinga2 pki"

    PKI_KEY="/etc/icinga2/pki/${HOSTNAME}.key"
    PKI_CSR="/etc/icinga2/pki/${HOSTNAME}.csr"
    PKI_CRT="/etc/icinga2/pki/${HOSTNAME}.crt"

    icinga2 api setup > /dev/null

    if [ $? -gt 0 ]
    then
      echo " [E] API Setup has failed"
      rm -f /etc/icinga2/pki/*
      rm -rf /var/lib/icinga2/ca
      rm -rf ${WORK_DIR}/pki
      rm -rf ${WORK_DIR}/ca

      exit 1
    fi

    ${PKI_CMD} new-cert --cn ${HOSTNAME} --key ${PKI_KEY} --csr ${PKI_CSR}
    ${PKI_CMD} sign-csr --csr ${PKI_CSR} --cert ${PKI_CRT}

    correct_rights

    /usr/sbin/icinga2 \
      daemon \
      --validate \
      --config /etc/icinga2/icinga2.conf \
      --errorlog /var/log/icinga2/error.log

    if [ $? -gt 0 ]
    then
      exit $?
    fi

    echo " [i] Finished cert generation"
  fi

  cp -ar /etc/icinga2/pki    ${WORK_DIR}/
  cp -ar /var/lib/icinga2/ca ${WORK_DIR}/

  restore_old_zone_config
}

# configure a icinga2 satellite instance
#
configure_icinga2_satellite() {

  echo " [i] we are an satellite .."

  export ICINGA_SATELLITE=true

  . /init/wait_for/cert_service.sh
  . /init/wait_for/icinga_master.sh

  if [ -e /etc/icinga2/features-enabled/notification.conf ]
  then
    disable_icinga_feature notification
  fi

  enable_icinga_feature api

  get_certificate

  # restore an old master name
  #
  [ -f ${WORK_DIR}/pki/${HOSTNAME}/master ] && master_name=$(cat ${WORK_DIR}/pki/${HOSTNAME}/master)

  echo " [i] configure the endpoint: '${master_name}'"

  # now, we configure our satellite
  if ( [ $(grep -c "Endpoint \"${master_name}\"" /etc/icinga2/zones.conf ) -eq 0 ] || [ $(grep -c "host = \"${ICINGA_MASTER}\"" /etc/icinga2/zones.conf) -eq 0 ] )
  then
    cat << EOF > /etc/icinga2/zones.conf

object Endpoint "${master_name}" {
  ### Folgende Zeile legt fest, dass der Client die Verbindung zum Master aufbaut und nicht umgekehrt
  host = "${ICINGA_MASTER}"
  port = "5665"
}

object Zone "master" {
  endpoints = [ "${master_name}" ]
}

object Endpoint NodeName {
}

object Zone ZoneName {
  endpoints = [ NodeName ]
  parent = "master"
}

object Zone "global-templates" {
  global = true
}

object Zone "director-global" {
  global = true
}

EOF
  fi

  for file in hosts.conf services.conf
  do
    [ -f /etc/icinga2/conf.d/${file} ]    && mv /etc/icinga2/conf.d/${file} /etc/icinga2/conf.d/${file}-SAVE
  done

  cp -a ${WORK_DIR}/pki/${HOSTNAME}/* /etc/icinga2/pki/

  correct_rights

  # test the configuration
  /usr/sbin/icinga2 \
    daemon \
    --validate \
    --config /etc/icinga2/icinga2.conf \
    --errorlog /var/log/icinga2/error.log
}

# for Master AND Satellite
#  - restore private key and certificate
#  - configure API Feature
#
restore_old_pki() {

  if [ -d ${WORK_DIR}/pki ]
  then

    echo " [i] restore older PKI settings for host '${HOSTNAME}'"

    find ${WORK_DIR}/pki -type f -name ${HOSTNAME}.csr -exec cp -a {} /etc/icinga2/pki/ \;
    find ${WORK_DIR}/pki -type f -name ${HOSTNAME}.key -exec cp -a {} /etc/icinga2/pki/ \;
    find ${WORK_DIR}/pki -type f -name ${HOSTNAME}.crt -exec cp -a {} /etc/icinga2/pki/ \;
    find ${WORK_DIR}/pki -type f -name ca.crt -exec cp -a {} /etc/icinga2/pki/ \;

    enable_icinga_feature api
  fi

  create_api_config
}

# create API config file
#
create_api_config() {

  if [ -f /etc/icinga2/features-available/api.conf ]
    then
      cat << EOF > /etc/icinga2/features-available/api.conf

object ApiListener "api" {
  cert_path = SysconfDir + "/icinga2/pki/" + NodeName + ".crt"
  key_path = SysconfDir + "/icinga2/pki/" + NodeName + ".key"
  ca_path = SysconfDir + "/icinga2/pki/ca.crt"

  accept_config = true
  accept_commands = true

  ticket_salt = TicketSalt
}

EOF

  fi
}


# restore a ols zone file for automatic generated satellites
#
restore_old_zone_config() {

  if [ -d ${WORK_DIR}/automatic-zones.d ]
  then
    echo " [i] restore older zone configurations"

    [ -d /etc/icinga2/automatic-zones.d ] || mkdir -vp /etc/icinga2/automatic-zones.d

    cp -a ${WORK_DIR}/automatic-zones.d/* /etc/icinga2/automatic-zones.d/
  fi
}


# ----------------------------------------------------------------------

restore_old_pki

if ( [ ! -z ${ICINGA_MASTER} ] && [ "${ICINGA_MASTER}" == "${HOSTNAME}" ] )
then

  configure_icinga2_master

  nohup /init/inotify.sh > /tmp/inotify.log 2>&1 &
else

  configure_icinga2_satellite
fi


# EOF


# Supported commands for pki command:
#   * pki new-ca (sets up a new CA)
#   * pki new-cert (creates a new CSR)
#     Command options:
#       --cn arg                  Common Name
#       --key arg                 Key file path (output
#       --csr arg                 CSR file path (optional, output)
#       --cert arg                Certificate file path (optional, output)
#   * pki request (requests a certificate)
#     Command options:
#       --key arg                 Key file path (input)
#       --cert arg                Certificate file path (input + output)
#       --ca arg                  CA file path (output)
#       --trustedcert arg         Trusted certificate file path (input)
#       --host arg                Icinga 2 host
#       --port arg                Icinga 2 port
#       --ticket arg              Icinga 2 PKI ticket
#   * pki save-cert (saves another Icinga 2 instance's certificate)
#     Command options:
#       --key arg                 Key file path (input), obsolete
#       --cert arg                Certificate file path (input), obsolete
#       --trustedcert arg         Trusted certificate file path (output)
#       --host arg                Icinga 2 host
#       --port arg (=5665)        Icinga 2 port
#   * pki sign-csr (signs a CSR)
#     Command options:
#       --csr arg                 CSR file path (input)
#       --cert arg                Certificate file path (output)
#   * pki ticket (generates a ticket)
#     Command options:
#       --cn arg                  Certificate common name
#       --salt arg                Ticket salt

