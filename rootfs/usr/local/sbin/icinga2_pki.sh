#!/bin/bash

ICINGA_CERT_SERVICE=${ICINGA_CERT_SERVICE:-false}
ICINGA_CERT_SERVICE_BA_USER=${ICINGA_CERT_SERVICE_BA_USER:-"admin"}
ICINGA_CERT_SERVICE_BA_PASSWORD=${ICINGA_CERT_SERVICE_BA_PASSWORD:-"admin"}
ICINGA_CERT_SERVICE_API_USER=${ICINGA_CERT_SERVICE_API_USER:-""}
ICINGA_CERT_SERVICE_API_PASSWORD=${ICINGA_CERT_SERVICE_API_PASSWORD:-""}
ICINGA_CERT_SERVICE_SERVER=${ICINGA_CERT_SERVICE_SERVER:-"localhost"}
ICINGA_CERT_SERVICE_PORT=${ICINGA_CERT_SERVICE_PORT:-"80"}

# ICINGA_MASTER must be an FQDN or an IP

# -------------------------------------------------------------------------------------------------

if [ ! ${ICINGA_CLUSTER} ]
then
  echo "we need no cluster config .."

  return
fi


# for Master AND  Satelitte
# icinga2 API cert - restore private key and certificate
#
if [ -d ${WORK_DIR}/pki ]
then

  echo " [i] restore older PKI settings for host '${HOSTNAME}'"

  find ${WORK_DIR}/pki -type f -name ${HOSTNAME}.key -o -name ${HOSTNAME}.crt -o -name ${HOSTNAME}.csr -exec cp -av {} /etc/icinga2/pki/ \;
  find ${WORK_DIR}/pki -type f -name ca.crt       -exec cp -av {} /etc/icinga2/pki/ \;

  if [ $(icinga2 feature list | grep Enabled | grep -c api) -eq 0 ]
  then
    icinga2 feature enable api
  fi
fi

  if ( [ ! -z ${ICINGA_MASTER} ] && [ ${ICINGA_MASTER} == ${HOSTNAME} ] )
  then

    echo " [i] we are the master .."

    # icinga2 cert - restore CA
    if [ ! -d /var/lib/icinga2/ca ]
    then

      echo " [i] restore older CA"
      if [ -d ${WORK_DIR}/ca ]
      then
        cp -ar ${WORK_DIR}/ca               /var/lib/icinga2/
      else

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

      [ -d ${WORK_DIR}/pki ] || mkdir ${WORK_DIR}/pki

      PKI_CMD="icinga2 pki"

      PKI_KEY="/etc/icinga2/pki/${HOSTNAME}.key"
      PKI_CSR="/etc/icinga2/pki/${HOSTNAME}.csr"
      PKI_CRT="/etc/icinga2/pki/${HOSTNAME}.crt"

      icinga2 api setup

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

  else

    echo " [i] we are an satellite .."

    [ -f /etc/supervisor.d/icinga2-cert-service.ini ] && rm -f /etc/supervisor.d/icinga2-cert-service.ini

    waitForIcingaMaster

    if [ -e /etc/icinga2/features-enabled/notification.conf ]
    then
      icinga2 feature disable notification
    fi

    if [ $(icinga2 feature list | grep Enabled | grep -c api) -eq 0 ]
    then
      icinga2 feature enable api
    fi

    if ( [ ! -d ${WORK_DIR}/pki/${HOSTNAME} ] || [ ! -f ${WORK_DIR}/pki/${HOSTNAME}/${HOSTNAME}.key ] )
    then

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

          echo " [i] we ask our cert-service for a certificate .."

          code=$(curl \
            --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
            --silent \
            --request GET \
            --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
            --header "X-API-KEY: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
            --write-out "%{http_code}\n" \
            --output /tmp/request_${HOSTNAME}.json \
            http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}/v2/request/${HOSTNAME})

          if ( [ $? -eq 0 ] && [ ${code} -eq 200 ] )
          then

            echo " [i] certifiacte request are successful"
            echo " [i] download and install it"

            masterName=$(jq --raw-output .masterName /tmp/request_${HOSTNAME}.json)
            checksum=$(jq --raw-output .checksum /tmp/request_${HOSTNAME}.json)

            rm -f /tmp/request_${HOSTNAME}.json

            mkdir -vp ${WORK_DIR}/pki/${HOSTNAME}

            # get our created cert
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
               http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}/v2/cert/${HOSTNAME}

            cd ${WORK_DIR}/pki/${HOSTNAME}

            if [ ! -f ${HOSTNAME}.tgz ]
            then
              echo " [E] Cert File '${HOSTNAME}.tgz' not found!"

              exit 1
            fi

            tar -xzf ${HOSTNAME}.tgz

            echo "${masterName}" > ${WORK_DIR}/pki/${HOSTNAME}/master
          else
            echo " [E] ${code} - the cert-service has an error."
            exit 1
          fi
        fi
      fi
    fi

    if [ -f ${WORK_DIR}/pki/${HOSTNAME}/master ]
    then
      masterName=$(cat ${WORK_DIR}/pki/${HOSTNAME}/master)
    fi

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

    if [ -f /etc/icinga2/conf.d/hosts.conf ]
    then
      mv /etc/icinga2/conf.d/hosts.conf /etc/icinga2/conf.d/hosts.conf-SAVE
    fi

    if [ -f /etc/icinga2/conf.d/services.conf ]
    then
      mv /etc/icinga2/conf.d/services.conf /etc/icinga2/conf.d/services.conf-SAVE
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

    cp -av ${WORK_DIR}/pki/${HOSTNAME}/* /etc/icinga2/pki/

    correctRights

    # test the configuration
    icinga2 daemon --validate -c /etc/icinga2/icinga2.conf

  fi


# EOF

