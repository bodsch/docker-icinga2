
# wait for the Certificate Service
#
wait_for_icinga_cert_service() {

  # the CERT-Service API use an Basic-Auth as first Authentication *AND*
  # use an own API Userr
  if [[ ${ICINGA_CERT_SERVICE} ]]
  then

    # use the new Cert Service to create and get a valide certificat for distributed icinga services
    #
    if (
      [[ ! -z ${ICINGA_CERT_SERVICE_BA_USER} ]] &&
      [[ ! -z ${ICINGA_CERT_SERVICE_BA_PASSWORD} ]] &&
      [[ ! -z ${ICINGA_CERT_SERVICE_API_USER} ]] &&
      [[ ! -z ${ICINGA_CERT_SERVICE_API_PASSWORD} ]]
    )
    then

      RETRY=35
      # wait for the running cert-service
      #
      until [[ ${RETRY} -le 0 ]]
      do
        nc -z ${ICINGA_CERT_SERVICE_SERVER} ${ICINGA_CERT_SERVICE_PORT} < /dev/null > /dev/null

        [[ $? -eq 0 ]] && break

        sleep 5s
        RETRY=$(expr ${RETRY} - 1)
      done

<<<<<<< HEAD
      if [[ ${RETRY} -le 0 ]]
=======
      if [[ $RETRY -le 0 ]]
>>>>>>> 4227dcece413b6dcdd8013ae6d1b490572a1d41d
      then
        log_error "Could not connect to the Certificate-Service '${ICINGA_CERT_SERVICE_SERVER}'"
        exit 1
      fi

      # okay, the web service is available
      # but, we have a problem, when he runs behind a proxy ...
      # eg.: https://monitoring-proxy.tld/cert-cert-service
      #

      RETRY=30
      # wait for the cert-service health check behind a proxy
      #
      until [[ ${RETRY} -le 0 ]]
      do

        health=$(curl \
          --silent \
          --request GET \
          --write-out "%{http_code}\n" \
          --request GET \
          http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}${ICINGA_CERT_SERVICE_PATH}v2/health-check)

        if ( [[ $? -eq 0 ]] && [[ "${health}" == "healthy200" ]] )
        then
          break
        fi

        health=

        log_info "wait for the health check for the cert-service on '${ICINGA_CERT_SERVICE_SERVER}'"
        sleep 5s
        RETRY=$(expr ${RETRY} - 1)
      done

      if [[ ${RETRY} -le 0 ]]
      then
        log_error "Could not a Health Check from the Certificate-Service '${ICINGA_CERT_SERVICE_SERVER}'"
        exit 1
      fi

      sleep 5s
    fi
  else
    log_warn "missing variables:"
    log_warn"     ICINGA_CERT_SERVICE_BA_USER: '${ICINGA_CERT_SERVICE_BA_USER}'"
    log_warn"     ICINGA_CERT_SERVICE_BA_PASSWORD: '${ICINGA_CERT_SERVICE_BA_PASSWORD}'"
    log_warn"     ICINGA_CERT_SERVICE_API_USER: '${ICINGA_CERT_SERVICE_API_USER}'"
    log_warn"     ICINGA_CERT_SERVICE_API_PASSWORD: '${ICINGA_CERT_SERVICE_API_PASSWORD}'"
  fi
}

wait_for_icinga_cert_service
