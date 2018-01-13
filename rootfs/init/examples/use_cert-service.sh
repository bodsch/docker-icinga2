
# useful for Icinga2 <2.8

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

  master_name=$(jq --raw-output .master_name /tmp/request_${HOSTNAME}.json)
  checksum=$(jq --raw-output .checksum /tmp/request_${HOSTNAME}.json)

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
