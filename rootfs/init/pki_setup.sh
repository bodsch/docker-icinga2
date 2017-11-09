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

# wait for the Icinga2 Master
#
wait_for_icinga_master() {

  if [ ${ICINGA_CLUSTER} == false ]
  then
    return
  fi

  RETRY=50

  until [ ${RETRY} -le 0 ]
  do
    nc -z ${ICINGA_MASTER} 5665 < /dev/null > /dev/null

    [ $? -eq 0 ] && break

    echo " [i] Waiting for icinga master to come up"

    sleep 10s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [ $RETRY -le 0 ]
  then
    echo " [E] could not connect to the icinga2 master instance '${ICINGA_MASTER}'"
    exit 1
  fi

  sleep 20s
}

# wait for the Certificate Service
#
waitForTheCertService() {

  # the CERT-Service API use an Basic-Auth as first Authentication *AND*
  # use an own API Userr
  if [ ${ICINGA_CERT_SERVICE} ]
  then

    # use the new Cert Service to create and get a valide certificat for distributed icinga services
    if (
      [ ! -z ${ICINGA_CERT_SERVICE_BA_USER} ] && [ ! -z ${ICINGA_CERT_SERVICE_BA_PASSWORD} ] &&
      [ ! -z ${ICINGA_CERT_SERVICE_API_USER} ] && [ ! -z ${ICINGA_CERT_SERVICE_API_PASSWORD} ]
    )
    then

      RETRY=30
      # wait for the running cert-service
      #
      until [ ${RETRY} -le 0 ]
      do
        nc -z ${ICINGA_CERT_SERVICE_SERVER} ${ICINGA_CERT_SERVICE_PORT} < /dev/null > /dev/null

        [ $? -eq 0 ] && break

        echo " [i] wait for the cert-service on '${ICINGA_CERT_SERVICE_SERVER}'"

        sleep 10s
        RETRY=$(expr ${RETRY} - 1)
      done

      if [ $RETRY -le 0 ]
      then
        echo " [E] Could not connect to the Certificate-Service '${ICINGA_CERT_SERVICE_SERVER}'"
        exit 1
      fi

      # okay, the web service is available
      # but, we have a problem, when he runs behind a proxy ...
      # eg.: https://monitoring-proxy.tld/cert-cert-service
      #

      RETRY=30
      # wait for the cert-service health check behind a proxy
      #
      until [ ${RETRY} -le 0 ]
      do

        health=$(curl \
          --silent \
          --request GET \
          --write-out "%{http_code}\n" \
          --request GET \
          http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/health-check)

        if ( [ $? -eq 0 ] && [ "${health}" == "healthy200" ] )
        then
          break
        fi

        health=

        echo " [i] wait for the health check for the cert-service on '${ICINGA_CERT_SERVICE_SERVER}'"
        sleep 10s
        RETRY=$(expr ${RETRY} - 1)
      done

      if [ $RETRY -le 0 ]
      then
        echo " [E] Could not a Health Check from the Certificate-Service '${ICINGA_CERT_SERVICE_SERVER}'"
        exit 1
      fi

      sleep 5s

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

        masterName=$(jq --raw-output .master_name /tmp/request_${HOSTNAME}.json)
        checksum=$(jq --raw-output .checksum /tmp/request_${HOSTNAME}.json)

#        rm -f /tmp/request_${HOSTNAME}.json

        mkdir -p ${WORK_DIR}/pki/${HOSTNAME}

        # get our created cert
        #
        curl \
          --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
          --silent \
          --request GET \
          --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
          --header "X-API-KEY: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
          --header "X-CHECKSUM: ${checksum}" \
          --write-out "%{http_code}\n" \
          --request GET \
          --output ${WORK_DIR}/pki/${HOSTNAME}/${HOSTNAME}.tgz \
          http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/cert/${HOSTNAME}

        cd ${WORK_DIR}/pki/${HOSTNAME}

        # the download has not working
        #
        if [ ! -f ${HOSTNAME}.tgz ]
        then
          echo " [E] Cert File '${HOSTNAME}.tgz' not found!"
          exit 1
        fi

        tar -xzf ${HOSTNAME}.tgz

        # store the master for later restart
        #
        echo "${masterName}" > ${WORK_DIR}/pki/${HOSTNAME}/master
      else
        error=$(cat /tmp/request_${HOSTNAME}.json)
        echo " [E] ${code} - the cert-service has an error: ${error}"
        rm -f /tmp/request_${HOSTNAME}.json
        exit 1
      fi

    fi
  fi
}


# wait for the Certificate Service
#
wait_for_icinga_cert_service() {

  # the CERT-Service API use an Basic-Auth as first Authentication *AND*
  # use an own API Userr
  if [ ${ICINGA_CERT_SERVICE} ]
  then

    # use the new Cert Service to create and get a valide certificat for distributed icinga services
    if (
      [ ! -z ${ICINGA_CERT_SERVICE_BA_USER} ] && [ ! -z ${ICINGA_CERT_SERVICE_BA_PASSWORD} ] &&
      [ ! -z ${ICINGA_CERT_SERVICE_API_USER} ] && [ ! -z ${ICINGA_CERT_SERVICE_API_PASSWORD} ]
    )
    then

      RETRY=30
      # wait for the running cert-service
      #
      until [ ${RETRY} -le 0 ]
      do
        nc -z ${ICINGA_CERT_SERVICE_SERVER} ${ICINGA_CERT_SERVICE_PORT} < /dev/null > /dev/null

        [ $? -eq 0 ] && break

        echo " [i] wait for the cert-service on '${ICINGA_CERT_SERVICE_SERVER}'"

        sleep 15s
        RETRY=$(expr ${RETRY} - 1)
      done

      if [ $RETRY -le 0 ]
      then
        echo " [E] Could not connect to the Certificate-Service '${ICINGA_CERT_SERVICE_SERVER}'"
        exit 1
      fi

      # okay, the web service is available
      # but, we have a problem, when he runs behind a proxy ...
      # eg.: https://monitoring-proxy.tld/cert-cert-service
      #

      RETRY=30
      # wait for the cert-service health check behind a proxy
      #
      until [ ${RETRY} -le 0 ]
      do

        health=$(curl \
          --silent \
          --request GET \
          --write-out "%{http_code}\n" \
          --request GET \
          http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/health-check)

        if ( [ $? -eq 0 ] && [ "${health}" == "healthy200" ] )
        then
          break
        fi

        health=

        echo " [i] wait for the health check for the cert-service on '${ICINGA_CERT_SERVICE_SERVER}'"
        sleep 15s
        RETRY=$(expr ${RETRY} - 1)
      done

      if [ $RETRY -le 0 ]
      then
        echo " [E] Could not a Health Check from the Certificate-Service '${ICINGA_CERT_SERVICE_SERVER}'"
        exit 1
      fi

      sleep 5s
    fi
  fi
}


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

      masterName=$(jq --raw-output .master_name /tmp/request_${HOSTNAME}.json)
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
      echo "${masterName}" > ${WORK_DIR}/pki/${HOSTNAME}/master
      else
        echo " [E] can't download out certificate!"

        rm -rf ${WORK_DIR}/pki 2> /dev/null

        unset ICINGA_API_PKI_PATH
      fi
    else

      echo " [E] ${code} - the cert-service has an error."
      cat /tmp/request_${HOSTNAME}.json

      rm -f /tmp/request_${HOSTNAME}.json
      exit 1
    fi
  fi
}


validate_local_ca() {

  if [ -f ${WORK_DIR}/pki/${HOSTNAME}/ca.crt ]
  then
    CHECKSUM=$(sha256sum ${WORK_DIR}/pki/${HOSTNAME}/ca.crt | cut -f 1 -d ' ')

    # generate a certificate request
    #
    code=$(curl \
      --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --request GET \
      --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
      --header "X-API-KEY: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
      --write-out "%{http_code}\n" \
      --output /tmp/validate_ca_${HOSTNAME}.json \
      http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/validate/${CHECKSUM})

    if ( [ $? -eq 0 ] && [ ${code} == 200 ] )
    then
      rm -f /tmp/validate_ca_${HOSTNAME}.json
    else

      status=$(echo "${code}" | jq --raw-output .status 2> /dev/null)
      message=$(echo "${code}" | jq --raw-output '.message' 2> /dev/null)

      echo " [w] our master has a new CA"
      echo -n "     "
      echo "${message}"

      rm -rf ${WORK_DIR}/pki
      rm -rf /etc/icinga2/pki/*

      rm -f /etc/icinga2/features-available/api.conf
      touch /etc/icinga2/features-available/api.conf
    fi
  else
    :
  fi
}


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


# configure a Icinga2 Master Instance
#
configureIcinga2Master() {

  echo " [i] we are the master .."

  # icinga2 cert - restore CA
  if [ ! -d /var/lib/icinga2/ca ]
  then
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

    correctRights

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

  restoreOldZoneConfig
}

# configure a Icinga2 Satellite Instance
#
configureIcinga2Satellite() {

  echo " [i] we are an satellite .."

  wait_for_icinga_master
  validate_cert

  if [ -e /etc/icinga2/features-enabled/notification.conf ]
  then
    icinga2 feature disable notification
  fi

  enableIcingaFeature api

  wait_for_icinga_cert_service
  get_certificate

#   if ( [ ! -d ${WORK_DIR}/pki/${HOSTNAME} ] || [ ! -f ${WORK_DIR}/pki/${HOSTNAME}/${HOSTNAME}.key ] )
#   then
#     waitForTheCertService
#   fi

  # restore an old master name
  #
  [ -f ${WORK_DIR}/pki/${HOSTNAME}/master ] && masterName=$(cat ${WORK_DIR}/pki/${HOSTNAME}/master)

  # now, we configure our satellite
  if ( [ $(grep -c "Endpoint \"${masterName}\"" /etc/icinga2/zones.conf ) -eq 0 ] || [ $(grep -c "host = \"${ICINGA_MASTER}\"" /etc/icinga2/zones.conf) -eq 0 ] )
  then
    cat << EOF > /etc/icinga2/zones.conf

object Endpoint "${masterName}" {
  ### Folgende Zeile legt fest, dass der Client die Verbindung zum Master aufbaut und nicht umgekehrt
  host = "${ICINGA_MASTER}"
  port = "5665"
}

object Zone "master" {
  endpoints = [ "${masterName}" ]
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

EOF
  fi

  for file in hosts.conf services.conf
  do
    [ -f /etc/icinga2/conf.d/${file} ]    && mv /etc/icinga2/conf.d/${file} /etc/icinga2/conf.d/${file}-SAVE
  done

  cp -a ${WORK_DIR}/pki/${HOSTNAME}/* /etc/icinga2/pki/

  correctRights

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
restoreOldPKI() {

  if [ -d ${WORK_DIR}/pki ]
  then

    echo " [i] restore older PKI settings for host '${HOSTNAME}'"

    find ${WORK_DIR}/pki -type f -name ${HOSTNAME}.csr -exec cp -av {} /etc/icinga2/pki/ \;
    find ${WORK_DIR}/pki -type f -name ${HOSTNAME}.key -exec cp -av {} /etc/icinga2/pki/ \;
    find ${WORK_DIR}/pki -type f -name ${HOSTNAME}.crt -exec cp -av {} /etc/icinga2/pki/ \;
    find ${WORK_DIR}/pki -type f -name ca.crt -exec cp -av {} /etc/icinga2/pki/ \;

    enableIcingaFeature api
  fi


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

restoreOldZoneConfig() {

  if [ -d ${WORK_DIR}/automatic-zones.d ]
  then
    echo " [i] restore older zone configurations"

    [ -d /etc/icinga2/automatic-zones.d ] || mkdir -vp /etc/icinga2/automatic-zones.d

    cp -a ${WORK_DIR}/automatic-zones.d/* /etc/icinga2/automatic-zones.d/
  fi
}


# ----------------------------------------------------------------------

restoreOldPKI

if ( [ ! -z ${ICINGA_MASTER} ] && [ "${ICINGA_MASTER}" == "${HOSTNAME}" ] )
then

  configureIcinga2Master

  nohup /init/inotify.sh > /tmp/inotify.log 2>&1 &
else

  configureIcinga2Satellite
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

