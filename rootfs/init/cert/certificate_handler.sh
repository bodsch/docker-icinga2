

# create a local CA for the icinga2 master
#
create_ca() {

  # create the CA, when they not exist
  #
  if [[ ! -f ${ICINGA_LIB_DIR}/ca/ca.crt ]]
  then
    log_info "create new CA"

    [[ -f ${PKI_KEY_FILE} ]] && rm -rf ${ICINGA_CERT_DIR}/${HOSTNAME}*

    icinga2 api setup

    # api setup has failed
    # we remove all cert related directies and files and leave the container
    # after an restart, we start from scratch
    #
    if [[ $? -gt 0 ]]
    then
      log_error "API Setup has failed"
      rm -rf ${ICINGA_LIB_DIR}/ca 2> /dev/null
      rm -rf ${ICINGA_CERT_DIR}/${HOSTNAME}* 2> /dev/null

      exit 1
    fi
  fi

  # icinga2 API cert - regenerate new private key and certificate when running in a new container
  #
  if [[ ! -f ${ICINGA_CERT_DIR}/${HOSTNAME}.key ]]
  then
    log_info "create new certificate"

    ${PKI_CMD} new-cert --cn ${HOSTNAME} --key ${PKI_KEY_FILE} --csr ${PKI_CSR_FILE}
    ${PKI_CMD} sign-csr --csr ${PKI_CSR_FILE} --cert ${PKI_CRT_FILE}

    correct_rights

    /usr/sbin/icinga2 \
      daemon \
      --validate \
      --config /etc/icinga2/icinga2.conf \
      --errorlog /var/log/icinga2/error.log

    if [[ $? -gt 0 ]]
    then
      exit $?
    fi

    chown -R icinga:icinga ${ICINGA_CERT_DIR}
    chmod 600 ${ICINGA_CERT_DIR}/*.key
    chmod 644 ${ICINGA_CERT_DIR}/*.crt

    log_info "Finished cert generation"
  fi
}


# validate our lokal certificate against our certificate service
# with an API Request against
# http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/validate/${checksum})
#
# if this failed, the PKI schould be removed
#
validate_local_ca() {

  if [[ -f ${ICINGA_CERT_DIR}/ca.crt ]]
  then

    log_info "validate our CA file against our master"

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

    if ( [[ $? -eq 0 ]] && [[ "${code}" = "200" ]] )
    then
      rm -f /tmp/validate_ca_${HOSTNAME}.json
    else

      status=$(echo "${code}" | jq --raw-output .status 2> /dev/null)
      message=$(echo "${code}" | jq --raw-output .message 2> /dev/null)

      log_warn "our master has a new CA"
      cat /tmp/validate_ca_${HOSTNAME}.json
      log_warn "${message}"

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

  if ( [[ -d ${ICINGA_CERT_DIR} ]] && [[ ! -f ${ICINGA_CERT_DIR}/${HOSTNAME}.pem ]] )
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
#     log_info "validate our certifiacte"
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

