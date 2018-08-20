
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

      . /init/wait_for/dns.sh
      . /init/wait_for/port.sh

      wait_for_dns ${CERT_SERVICE_SERVER}
      wait_for_port ${CERT_SERVICE_SERVER} ${CERT_SERVICE_PORT} 50

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
          --write-out "%{http_code}\n" \
          ${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/health-check)

        if ( [[ $? -eq 0 ]] && [[ "${health}" == "healthy200" ]] )
        then
          break
        fi

        health=

        log_info "wait for the health check for the certificate service on '${CERT_SERVICE_SERVER}'"
        sleep 5s
        RETRY=$(expr ${RETRY} - 1)
      done

      if [[ ${RETRY} -le 0 ]]
      then
        log_error "The certificate service '${CERT_SERVICE_SERVER}' could not be reached"
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
