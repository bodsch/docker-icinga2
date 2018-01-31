
# useful for Icinga2 <2.8

  # generate a certificate request
  #
  code=$(curl \
    --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
    --silent \
    --request GET \
    --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
    --header "X-API-KEY: ${CERT_SERVICE_API_PASSWORD}" \
    --write-out "%{http_code}\n" \
    --output /tmp/request_${HOSTNAME}.json \
    http://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/request/${HOSTNAME})

  master_name=$(jq --raw-output .master_name /tmp/request_${HOSTNAME}.json)
  checksum=$(jq --raw-output .checksum /tmp/request_${HOSTNAME}.json)

  # get our created cert
  #
  code=$(curl \
    --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
    --silent \
    --request GET \
    --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
    --header "X-API-KEY: ${CERT_SERVICE_API_PASSWORD}" \
    --header "X-CHECKSUM: ${checksum}" \
    --write-out "%{http_code}\n" \
    --request GET \
    --output ${WORK_DIR}/pki/${HOSTNAME}/${HOSTNAME}.tgz \
    http://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/cert/${HOSTNAME})
