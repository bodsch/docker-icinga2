

# create a local CA
#
create_ca() {

  # create the CA, when they not exist
  #
  if [ ! -f ${ICINGA_LIB_DIR}/ca/ca.crt ]
  then
    echo " [i] create new CA"

    if [ -f ${PKI_KEY_FILE} ]
    then
      rm -rf ${ICINGA_CERT_DIR}/${HOSTNAME}*
    fi

    icinga2 api setup

    # api setup has failed
    # we remove all cert related directies and files and leave the container
    # after an restart, we start from scratch
    #
    if [ $? -gt 0 ]
    then
      echo " [E] API Setup has failed"
      rm -rf ${ICINGA_LIB_DIR}/ca 2> /dev/null
      rm -rf ${ICINGA_CERT_DIR}/${HOSTNAME}* 2> /dev/null

      exit 1
    fi
  fi

  # icinga2 API cert - regenerate new private key and certificate when running in a new container
  #
  if [ ! -f ${ICINGA_CERT_DIR}/${HOSTNAME}.key ]
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

    chown -R icinga:icinga ${ICINGA_CERT_DIR}
    chmod 600 ${ICINGA_CERT_DIR}/*.key
    chmod 644 ${ICINGA_CERT_DIR}/*.crt

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

  if [ -f ${ICINGA_CERT_DIR}/ca.crt ]
  then

    echo " [i] validate our CA file against our master"

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

    if ( [ $? -eq 0 ] && [ "${code}" = "200" ] )
    then
      rm -f /tmp/validate_ca_${HOSTNAME}.json
    else

      status=$(echo "${code}" | jq --raw-output .status 2> /dev/null)
      message=$(echo "${code}" | jq --raw-output .message 2> /dev/null)

      echo " [W] our master has a new CA"

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


create_certificate_pem() {

  if ( [ -d ${ICINGA_CERT_DIR} ] && [ ! -f ${ICINGA_CERT_DIR}/${HOSTNAME}.pem ] )
  then
    cd ${ICINGA_CERT_DIR}

    cat ${HOSTNAME}.crt ${HOSTNAME}.key >> ${HOSTNAME}.pem
  fi
}

# validate our lokal certificate against our icinga-master
# with an API Request against https://${ICINGA_HOST}:${ICINGA_API_PORT}/v1/status/CIB
#
# if this failed, the PKI schould be removed
#
# validate_cert() {
#
#   if [ -d ${ICINGA_CERT_DIR}/ ]
#   then
#     cd ${ICINGA_CERT_DIR}
#
#     if [ ! -f ${HOSTNAME}.pem ]
#     then
#       cat ${HOSTNAME}.crt ${HOSTNAME}.key >> ${HOSTNAME}.pem
#     fi
#
#     echo " [i] validate our certifiacte"
#
#     code=$(curl \
#       --silent \
#       --insecure \
#       --user ${ICINGA_CERT_SERVICE_API_USER}:${ICINGA_CERT_SERVICE_API_PASSWORD} \
#       --capath . \
#       --cert ./${HOSTNAME}.pem \
#       --cacert ./ca.crt \
#       https://${ICINGA_MASTER}:5665/v1/status/CIB)
#
#     echo ${code}
#
# #     if [[ $? -gt 0 ]]
# #     then
# #       cd /
# #       rm -rf ${ICINGA_CERT_DIR}/*
# #     fi
#   fi
# }

