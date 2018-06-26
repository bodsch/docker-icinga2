
# wait for the Certificate Service
#
wait_for_icinga_cert_service() {

  # the CERT-Service API use an Basic-Auth as first Authentication *AND*
  # use an own API Userr
  if [[ "${USE_CERT_SERVICE}" = "true" ]]
  then

    # use the new Cert Service to create and get a valide certificat for distributed icinga services
    #
    if (
      [[ ! -z ${CERT_SERVICE_BA_USER} ]] &&
      [[ ! -z ${CERT_SERVICE_BA_PASSWORD} ]] &&
      [[ ! -z ${CERT_SERVICE_API_USER} ]] &&
      [[ ! -z ${CERT_SERVICE_API_PASSWORD} ]]
    )
    then

      log_info "Waiting for the Certificate-Service on host '${CERT_SERVICE_SERVER}' to come up"

      RETRY=35

      until [[ ${RETRY} -le 0 ]]
      do
        host=$(dig +noadditional +noqr +noquestion +nocmd +noauthority +nostats +nocomments ${CERT_SERVICE_SERVER} | wc -l)

        if [[ $host -eq 0 ]]
        then
          RETRY=$(expr ${RETRY} - 1)
          sleep 10s
        else
          break
        fi
      done


      # wait for the running cert-service
      #
      until [[ ${RETRY} -le 0 ]]
      do
        # -v              Verbose
        # -w secs         Timeout for connects and final net reads
        # -X proto        Proxy protocol: "4", "5" (SOCKS) or "connect"
        #
        status=$(nc -v -w1 -X connect ${CERT_SERVICE_SERVER} ${CERT_SERVICE_PORT} 2>&1)

        if [[ $(echo "${status}" | grep -c succeeded) -eq 1 ]]
        then
          break
        else
          sleep 5s
          RETRY=$(expr ${RETRY} - 1)
        fi
      done

      if [[ ${RETRY} -le 0 ]]
      then
        log_error "Could not connect to the Certificate-Service '${CERT_SERVICE_SERVER}'"
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
          --location \
          --insecure \
          --request GET \
          --write-out "%{http_code}\n" \
          --request GET \
          http://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/health-check)

        if ( [[ $? -eq 0 ]] && [[ "${health}" == "healthy200" ]] )
        then
          break
        fi

        health=

        log_info "wait for the health check for the cert-service on '${CERT_SERVICE_SERVER}'"
        sleep 5s
        RETRY=$(expr ${RETRY} - 1)
      done

      if [[ ${RETRY} -le 0 ]]
      then
        log_error "Could not a Health Check from the Certificate-Service '${CERT_SERVICE_SERVER}'"
        exit 1
      fi

      sleep 5s
    fi
  else
    log_warn "missing variables:"
    log_warn "     CERT_SERVICE_BA_USER: '${CERT_SERVICE_BA_USER}'"
    log_warn "     CERT_SERVICE_BA_PASSWORD: '${CERT_SERVICE_BA_PASSWORD}'"
    log_warn "     CERT_SERVICE_API_USER: '${CERT_SERVICE_API_USER}'"
    log_warn "     CERT_SERVICE_API_PASSWORD: '${CERT_SERVICE_API_PASSWORD}'"
  fi
}

wait_for_icinga_cert_service
