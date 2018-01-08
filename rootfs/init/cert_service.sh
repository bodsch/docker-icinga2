#!/bin/sh

ICINGA_CERT_SERVICE=${ICINGA_CERT_SERVICE:-false}
ICINGA_CERT_SERVICE_BA_USER=${ICINGA_CERT_SERVICE_BA_USER:-"admin"}
ICINGA_CERT_SERVICE_BA_PASSWORD=${ICINGA_CERT_SERVICE_BA_PASSWORD:-"admin"}
ICINGA_CERT_SERVICE_API_USER=${ICINGA_CERT_SERVICE_API_USER:-""}
ICINGA_CERT_SERVICE_API_PASSWORD=${ICINGA_CERT_SERVICE_API_PASSWORD:-""}
ICINGA_CERT_SERVICE_SERVER=${ICINGA_CERT_SERVICE_SERVER:-"localhost"}
ICINGA_CERT_SERVICE_PORT=${ICINGA_CERT_SERVICE_PORT:-"80"}
ICINGA_CERT_SERVICE_PATH=${ICINGA_CERT_SERVICE_PATH:-"/"}

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

        echo " [E] ${code} - the cert-service has an error."
        cat /tmp/request_${HOSTNAME}.json

        rm -f /tmp/request_${HOSTNAME}.json
        exit 1
      fi

    fi
  fi
}


waitForTheCertService

