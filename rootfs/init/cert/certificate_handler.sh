

# create a local CA for the icinga2 master
#
create_ca() {

  # create the CA, when they not exist
  #
  if [[ ! -f ${ICINGA2_LIB_DIRECTORY}/ca/ca.crt ]]
  then
    log_info "create new CA for '${HOSTNAME}'"

    [[ -f ${PKI_KEY_FILE} ]] && rm -rf ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}*

    icinga2 api setup

    # api setup has failed
    # we remove all cert related directies and files and leave the container
    # after an restart, we start from scratch
    #
    if [[ $? -gt 0 ]]
    then
      log_error "API Setup has failed"
      rm -rf ${ICINGA2_LIB_DIRECTORY}/ca 2> /dev/null
      rm -rf ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}* 2> /dev/null

      exit 1
    fi
  fi

  sed -i \
    -e "s|^.*\ NodeName\ \=\ .*|const\ NodeName\ \=\ \"${HOSTNAME}\"|g" \
    -e "s|^.*\ ZoneName\ \=\ .*|const\ ZoneName\ \=\ \"${HOSTNAME}\"|g" \
    /etc/icinga2/constants.conf

  # icinga2 API cert - regenerate new private key and certificate when running in a new container
  #
  if [[ ! -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ]]
  then
    log_info "create new certificate"

    ${PKI_CMD} new-cert --cn ${HOSTNAME} --key ${PKI_KEY_FILE} --csr ${PKI_CSR_FILE}
    ${PKI_CMD} sign-csr --csr ${PKI_CSR_FILE} --cert ${PKI_CRT_FILE}

    correct_rights

    /usr/sbin/icinga2 \
      daemon \
      --validate

    if [[ $? -gt 0 ]]
    then
      exit $?
    fi

    chown -R ${USER}:${GROUP} ${ICINGA2_CERT_DIRECTORY}
    chmod 600 ${ICINGA2_CERT_DIRECTORY}/*.key
    chmod 644 ${ICINGA2_CERT_DIRECTORY}/*.crt

    log_info "Finished cert generation"
  fi
}


# validate our lokal certificate against our certificate service
# with an API Request against
# http://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/validate/${checksum})
#
# if this failed, the PKI schould be removed
#
validate_local_ca() {

  if [[ -f ${ICINGA2_CERT_DIRECTORY}/ca.crt ]]
  then
    log_info "validate our CA file against our master"

    . /init/wait_for/cert_service.sh

    checksum=$(sha256sum ${ICINGA2_CERT_DIRECTORY}/ca.crt | cut -f 1 -d ' ')

    # validate our ca file
    #
    code=$(curl \
      --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --location \
      --insecure \
      --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
      --header "X-API-KEY: ${CERT_SERVICE_API_PASSWORD}" \
      --write-out "%{http_code}\n" \
      --output /tmp/validate_ca_${HOSTNAME}.json \
      ${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}/v2/validate/${checksum})

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

      rm -rf ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}*
      rm -rf ${ICINGA2_LIB_DIRECTORY}/ca/*

      cat /dev/null > /etc/icinga2/features-available/api.conf
    fi
  else
    # we have no local cert file ..
    :
  fi
}


create_certificate_pem() {

  if ( [[ -d ${ICINGA2_CERT_DIRECTORY} ]] && [[ ! -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.pem ]] )
  then
    cd ${ICINGA2_CERT_DIRECTORY}

    cat ${HOSTNAME}.crt ${HOSTNAME}.key >> ${HOSTNAME}.pem
  fi
}

# validate our lokal certificate against our icinga-master
# with an API Request against https://${ICINGA2_HOST}:${ICINGA2_API_PORT}/v1/status/CIB
#
# if this failed, the PKI schould be removed
#
# validate_cert() {
#
#   if [ -d ${ICINGA2_CERT_DIRECTORY}/ ]
#   then
#     cd ${ICINGA2_CERT_DIRECTORY}
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
#       --user ${CERT_SERVICE_API_USER}:${CERT_SERVICE_API_PASSWORD} \
#       --capath . \
#       --cert ./${HOSTNAME}.pem \
#       --cacert ./ca.crt \
#       https://${ICINGA2_MASTER}:5665/v1/status/CIB)
#
#     echo ${code}
#
# #     if [[ $? -gt 0 ]]
# #     then
# #       cd /
# #       rm -rf ${ICINGA2_CERT_DIRECTORY}/*
# #     fi
#   fi
# }

