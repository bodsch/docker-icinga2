#!/bin/sh

ICINGA_CERT_SERVICE=${ICINGA_CERT_SERVICE:-false}
ICINGA_CERT_SERVICE_BA_USER=${ICINGA_CERT_SERVICE_BA_USER:-"admin"}
ICINGA_CERT_SERVICE_BA_PASSWORD=${ICINGA_CERT_SERVICE_BA_PASSWORD:-"admin"}
ICINGA_CERT_SERVICE_API_USER=${ICINGA_CERT_SERVICE_API_USER:-""}
ICINGA_CERT_SERVICE_API_PASSWORD=${ICINGA_CERT_SERVICE_API_PASSWORD:-""}
ICINGA_CERT_SERVICE_SERVER=${ICINGA_CERT_SERVICE_SERVER:-"localhost"}
ICINGA_CERT_SERVICE_PORT=${ICINGA_CERT_SERVICE_PORT:-"80"}
ICINGA_CERT_SERVICE_PATH=${ICINGA_CERT_SERVICE_PATH:-"/"}

PKI_CMD="icinga2 pki"
PKI_KEY_FILE="${ICINGA_CERT_DIR}/${HOSTNAME}.key"
PKI_CSR_FILE="${ICINGA_CERT_DIR}/${HOSTNAME}.csr"
PKI_CRT_FILE="${ICINGA_CERT_DIR}/${HOSTNAME}.crt"

# ICINGA_MASTER must be an FQDN or an IP

# -------------------------------------------------------------------------------------------------

create_local_certificate() {

  if [ ! -f ${ICINGA_LIB_DIR}/ca/ca.crt ]
  then
    echo " [i] create new CA"

    if [ -f ${PKI_KEY_FILE} ]
    then
      rm -rf ${ICINGA_CERT_DIR}/${HOSTNAME}*
    fi

    icinga2 api setup  # > /dev/null

    # ${PKI_CMD} new-ca

    if [ $? -gt 0 ]
    then
      echo " [E] API Setup has failed"
      rm -rf ${ICINGA_LIB_DIR}/ca 2> /dev/null
      rm -rf ${ICINGA_CERT_DIR}/${HOSTNAME}* 2> /dev/null

      exit 1
    fi
  fi

  # icinga2 API cert - regenerate new private key and certificate when running in a new container
  if [ ! -f ${ICINGA_LIB_DIR}/certs/${HOSTNAME}.key ]
  then
    echo " [i] create new certificate"

    ${PKI_CMD} new-cert --cn ${HOSTNAME} --key ${PKI_KEY_FILE} --csr ${PKI_CSR_FILE}
    ${PKI_CMD} sign-csr --csr ${PKI_CSR_FILE} --cert ${PKI_CRT_FILE}

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

    chown -R icinga:icinga ${ICINGA_LIB_DIR}/certs
    chmod 600 ${ICINGA_LIB_DIR}/certs/*.key
    chmod 644 ${ICINGA_LIB_DIR}/certs/*.crt

    echo " [i] Finished cert generation"
  fi
}


# get a new icinga certificate from our icinga-master
#
#
# withicinga version 2.8 we dont need this codefragment
# this is also obsolete and will be removed in near future
#
get_certificate() {

  validate_local_ca

  if [ -f ${ICINGA_CERT_DIR}/${HOSTNAME}.key ]
  then
    return
  fi

  if [ ${ICINGA_CERT_SERVICE} ]
  then
    echo ""
    echo " [i] we ask our cert-service for a certificate .."

    code=$(curl \
      --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --request GET \
      http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/icinga-version)

    echo " [i] remote icinga version: ${code}"

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

  # TODO
  # we need this part?

  if [ -f ${ICINGA_CERT_DIR}/ca.crt ]
  then
    checksum=$(sha256sum ${ICINGA_CERT_DIR}/ca.crt | cut -f 1 -d ' ')

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

      rm -rf ${ICINGA_CERT_DIR}/${HOSTNAME}*
      rm -rf ${ICINGA_LIB_DIR}/ca/*

      cat /dev/null > /etc/icinga2/features-available/api.conf
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

  if [ -d ${ICINGA_CERT_DIR}/ ]
  then
    cd ${ICINGA_CERT_DIR}

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
      --cert ./${HOSTNAME}.pem \
      --cacert ./ca.crt \
      https://${ICINGA_MASTER}:5665/v1/status/CIB)

#     if [[ $? -gt 0 ]]
#     then
#       cd /
#       rm -rf ${ICINGA_CERT_DIR}/*
#     fi
  fi
}


# configure a icinga2 master instance
#
configure_icinga2_master() {

  echo " [i] we are the master .."

  enable_icinga_feature api

  create_local_certificate

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

  if ( [ -f ${ICINGA_CERT_DIR}/${HOSTNAME}.key ] && [ -f ${ICINGA_CERT_DIR}/${HOSTNAME}.crt ] )
  then
    validate_cert
  fi

  if ( [ -f ${ICINGA_CERT_DIR}/${HOSTNAME}.key ] && [ -f ${ICINGA_CERT_DIR}/${HOSTNAME}.crt ] )
  then
    [ -d ${ICINGA_LIB_DIR}/backup ] && cp -v ${ICINGA_LIB_DIR}/backup/zones.conf /etc/icinga2/zones.conf 2> /dev/null
  else

    expect /init/node-wizard.expect 1> /dev/null

    sleep 5s

    echo " [i] ask our cert-service to sign our certifiacte"

    code=$(curl \
      --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --request GET \
      --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
      --header "X-API-PASSWORD: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
      --write-out "%{http_code}\n" \
      --output /tmp/sign_${HOSTNAME}.json \
      http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/sign/${HOSTNAME})

    if [[ $? -gt 0 ]]
    then
      cat /tmp/sign_${HOSTNAME}.json
      rm -f /tmp/sign_${HOSTNAME}.json
    fi

    echo " [i] configure the endpoint: '${ICINGA_MASTER}'"

    # now, we configure our satellite
    if ( [ $(grep -c "Endpoint \"${ICINGA_MASTER}\"" /etc/icinga2/zones.conf ) -eq 0 ] || [ $(grep -c "host = \"${ICINGA_MASTER}\"" /etc/icinga2/zones.conf) -eq 0 ] )
    then
      cat << EOF > /etc/icinga2/zones.conf

object Endpoint "${ICINGA_MASTER}" {
  ### Folgende Zeile legt fest, dass der Client die Verbindung zum Master aufbaut und nicht umgekehrt
  host = "${ICINGA_MASTER}"
  port = "5665"
}

object Zone "master" {
  endpoints = [ "${ICINGA_MASTER}" ]
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
  fi


  for file in hosts.conf services.conf
  do
    [ -f /etc/icinga2/conf.d/${file} ]    && mv /etc/icinga2/conf.d/${file} /etc/icinga2/conf.d/${file}-SAVE
  done

  cp -a /etc/icinga2/zones.conf ${ICINGA_LIB_DIR}/backup/zones.conf

  correct_rights

  # test the configuration
  /usr/sbin/icinga2 \
    daemon \
    --validate \
    --config /etc/icinga2/icinga2.conf \
    --errorlog /dev/stderr
}


configure_icinga2_agent() {

  echo " [i] we are an agent .."

  # TODO
}


# create API config file
#
create_api_config() {

  if [ "${ICINGA_VERSION}" == "2.8" ]
  then
    # look at https://www.icinga.com/docs/icinga2/latest/doc/16-upgrading-icinga-2/#upgrading-to-v28
    if [ -f /etc/icinga2/features-available/api.conf ]
    then
      cat << EOF > /etc/icinga2/features-available/api.conf

object ApiListener "api" {
  accept_config = true
  accept_commands = true
  ticket_salt = TicketSalt
}

EOF
    fi
  else

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
  fi
}


# restore a ols zone file for automatic generated satellites
#
restore_old_zone_config() {

  if [ -d ${ICINGA_LIB_DIR}/backup/automatic-zones.d ]
  then
    echo " [i] restore older zone configurations"

    [ -d /etc/icinga2/automatic-zones.d ] || mkdir -vp /etc/icinga2/automatic-zones.d

    cp -a ${ICINGA_LIB_DIR}/backup/automatic-zones.d/* /etc/icinga2/automatic-zones.d/
  fi
}


# ----------------------------------------------------------------------

create_api_config

if [ "${ICINGA_TYPE_MASTER}" == "true" ]  # ( [ -z ${ICINGA_PARENT} ] && [ ! -z ${ICINGA_MASTER} ] && [ "${ICINGA_MASTER}" == "${HOSTNAME}" ] )
then
  configure_icinga2_master

  nohup /init/inotify.sh > /tmp/inotify-automatic-zones.log 2>&1 &
elif [ "${ICINGA_TYPE_SATELLITE}" == "true" ]  # ( [ ! -z ${ICINGA_PARENT} ] && [ ! -z ${ICINGA_MASTER} ] && [ "${ICINGA_MASTER}" == "${ICINGA_PARENT}" ] )
then
  configure_icinga2_satellite
else
  configure_icinga2_agent
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

