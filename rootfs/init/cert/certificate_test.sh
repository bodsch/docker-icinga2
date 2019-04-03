#!/bin/bash

. /etc/profile

. /init/output.sh
. /init/environment.sh

certificate_with_ticket() {

  [[ -d ${ICINGA2_CERT_DIRECTORY} ]] || mkdir -p ${ICINGA2_CERT_DIRECTORY}

  chmod a+w ${ICINGA2_CERT_DIRECTORY}

  if [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ]] && [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt ]]
  then
    return
  fi

  # create an ticket on the master via:
  #  icinga2 pki ticket --cn ${HOSTNAME}

  [[ "${DEBUG}" = "true" ]] && log_debug "ask for an PKI ticket"
  ticket=$(curl \
    --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
    --silent \
    --location \
    --insecure \
    --request GET \
    --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
    --header "X-API-PASSWORD: ${CERT_SERVICE_API_PASSWORD}" \
    "${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}/v2/ticket/${HOSTNAME}")

  # enable neccessary features
#  icinga2 feature enable api compatlog command

  # the following commands are copied out of the icinga2-documentation
  [[ "${DEBUG}" = "true" ]] && log_debug "pki new-cert"
  icinga2 pki new-cert \
    --log-level ${ICINGA2_LOGLEVEL} \
    --cn ${HOSTNAME} \
    --key ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key \
    --cert ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt

  [[ "${DEBUG}" = "true" ]] && log_debug "pki save-cert"
  icinga2 pki save-cert \
    --log-level ${ICINGA2_LOGLEVEL} \
    --trustedcert ${ICINGA2_CERT_DIRECTORY}/trusted-master.crt \
    --host ${ICINGA2_MASTER}

  [[ "${DEBUG}" = "true" ]] && log_debug "pki request"
  icinga2 pki request \
    --log-level ${ICINGA2_LOGLEVEL} \
    --host ${ICINGA2_MASTER} \
    --port ${ICINGA2_MASTER_PORT} \
    --ticket ${ticket} \
    --key ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key \
    --cert ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt \
    --trustedcert ${ICINGA2_CERT_DIRECTORY}/trusted-master.crt \
    --ca ${ICINGA2_CERT_DIRECTORY}/ca.crt

  #--endpoint ${ICINGA2_MASTER} \ # ,${ICINGA2_MASTER},${ICINGA2_MASTER_PORT} \

  [[ "${DEBUG}" = "true" ]] && log_debug "node setup"
  icinga2 node setup \
    --log-level ${ICINGA2_LOGLEVEL} \
    --accept-config \
    --accept-commands \
    --disable-confd \
    --cn ${HOSTNAME} \
    --zone ${HOSTNAME} \
    --endpoint ${ICINGA2_MASTER} \
    --parent_host ${ICINGA2_MASTER} \
    --parent_zone master \
    --ticket ${ticket} \
    --trustedcert ${ICINGA2_CERT_DIRECTORY}/trusted-master.crt

  date="$(date "+%Y-%m-%d %H:%M:%S")"
  timestamp="$(date "+%s")"

  cat << EOF > ${ICINGA2_LIB_DIRECTORY}/backup/sign_${HOSTNAME}.json
{
  "status": 200,
  "message": "PKI for ${HOSTNAME}",
  "master_name": "${ICINGA2_MASTER}",
  "master_ip": "",
  "date": "${date}",
  "timestamp": ${timestamp}
}
EOF
}



get_certificate_for_the_satellite() {

  local WORK_DIR=/tmp

  validate_local_ca

  if [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ]] && [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt ]] && [[ ${ICINGA2_CERT_DIRECTORY}/ca.crt ]]
  then
    return
  fi

#
#  if [ -f ${ICINGA_CERT_DIR}/${HOSTNAME}.key ]
#  then
#    return
#  fi

#  if [ ${ICINGA_CERT_SERVICE} ]
#  then
    log_info "we ask our cert-service for a certificate .."

set -x
    code=$(curl \
      --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --location \
      --insecure \
      --request GET \
      ${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/icinga-version)

    log_debug "remote icinga version: ${code}"

    # generate a certificate request
    #
    code=$(curl \
      --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --insecure \
      --request GET \
      --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
      --header "X-API-PASSWORD: ${CERT_SERVICE_API_PASSWORD}" \
      --write-out "%{http_code}\n" \
      --output /tmp/request_${HOSTNAME}.json \
      ${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/request/${HOSTNAME})

    if ( [ $? -eq 0 ] && [ ${code} -eq 200 ] )
    then

      log_info "certifiacte request was successful"
      log_info "download and install the certificate"

      master_name=$(jq --raw-output .master_name /tmp/request_${HOSTNAME}.json)
      checksum=$(jq    --raw-output .checksum    /tmp/request_${HOSTNAME}.json)

      cat /tmp/request_${HOSTNAME}.json

#      rm -f /tmp/request_${HOSTNAME}.json

      mkdir -p ${WORK_DIR}/pki/${HOSTNAME}

      # get our created cert
      #
      code=$(curl \
        --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
        --silent \
        --insecure \
        --request GET \
        --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
        --header "X-API-PASSWORD: ${CERT_SERVICE_API_PASSWORD}" \
        --header "X-CHECKSUM: ${checksum}" \
        --write-out "%{http_code}\n" \
        --output ${WORK_DIR}/pki/${HOSTNAME}/${HOSTNAME}.tgz \
        ${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/cert/${HOSTNAME})

      result="${?}"

      if [[ ${result} -eq 0 ]] && [[ ${code} -eq 200 ]]
      then

        cd ${WORK_DIR}/pki/${HOSTNAME}

        # the download has not working
        #
        if [[ ! -f ${HOSTNAME}.tgz ]]
        then
          log_error "cert File '${HOSTNAME}.tgz' not found!"
          exit 1
        fi

        tar -xzf ${HOSTNAME}.tgz

        ls -lth

        if [[ ! -f ${HOSTNAME}.pem ]]
        then
          cat ${HOSTNAME}.crt ${HOSTNAME}.key >> ${HOSTNAME}.pem
        fi

        cp -a ${HOSTNAME}.crt ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt
        cp -a ${HOSTNAME}.key ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key
        cp -a ${HOSTNAME}.pem ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.pem
        cp -a ca.crt ${ICINGA2_CERT_DIRECTORY}/ca.crt

        cp -a /tmp/request_${HOSTNAME}.json /var/lib/icinga2/backup/sign_${HOSTNAME}.json

        # store the master for later restart
        #
        echo "${master_name}" > ${WORK_DIR}/pki/${HOSTNAME}/master

        create_api_config

      else
        log_error "can't download our certificate!"

        rm -rf ${WORK_DIR}/pki 2> /dev/null

        unset ICINGA_API_PKI_PATH
      fi
    else

      error=$(cat /tmp/request_${HOSTNAME}.json)

      log_error "${code} - the cert-service tell us a problem: '${error}'"
      log_error "exit ..."

      rm -f /tmp/request_${HOSTNAME}.json

      exit 1
    fi
set +x

#  fi
}



request_certificate_from_master() {

  # we have a certificate
  # restore our own zone configuration
  # otherwise, we can't communication with the master
  #
  if ( [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ]] && [[ -f ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt ]] )
  then
    :
  else
    # no certificate found
    # use the node wizard to create a valid certificate request
    #

    log_info "use the node wizard to create a valid certificate request"
    expect /init/node-wizard.expect 1> /dev/null

    result=${?}

    if [[ "${DEBUG}" = "true" ]]
    then
      log_debug "the result for the node-wizard was '${result}'"
    fi

    # after this, in /var/lib/icinga2/certs/ should be found this files:
    #  - ca.crt
    #  - $(hostname -f).key
    #  - $(hostname -f).crt
    #
    # these files are absolutly importand for the nexts steps
    # we can abort immediately, if it should come to mistakes.

    sleep 8s

    # check transfered certificate files
    #
    BREAK="false"
    for f in ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.key ${ICINGA2_CERT_DIRECTORY}/${HOSTNAME}.crt ${ICINGA2_CERT_DIRECTORY}/ca.crt
    do
      if [[ -f ${f} ]]
      then
        :
        [[ "${DEBUG}" = "true" ]] && log_debug "file '${f}' exists!"
      else
        log_error "file '${f}' is missing!"
        BREAK="true"
      fi
    done

    if [[ ${BREAK} = "true" ]]
    then

      if [[ ! -f ${ICINGA2_CERT_DIRECTORY}/ca.crt ]]
      then
        get_ca_file
      fi
    fi

    # and now we have to ask our master to confirm this certificate
    #
    log_info "ask our cert-service to sign our certifiacte"

    . /init/wait_for/cert_service.sh

    code=$(curl \
      --user ${CERT_SERVICE_BA_USER}:${CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --location \
      --insecure \
      --header "X-API-USER: ${CERT_SERVICE_API_USER}" \
      --header "X-API-PASSWORD: ${CERT_SERVICE_API_PASSWORD}" \
      --write-out "%{http_code}\n" \
      --output /tmp/sign_${HOSTNAME}.json \
      ${CERT_SERVICE_PROTOCOL}://${CERT_SERVICE_SERVER}:${CERT_SERVICE_PORT}${CERT_SERVICE_PATH}v2/sign/${HOSTNAME})

    result=${?}

    if [[ "${DEBUG}" = "true" ]]
    then
      log_debug "result for sign certificate:"
      log_debug "result: '${result}' | code: '${code}'"
      log_debug "$(ls -lth /tmp/sign_${HOSTNAME}.json)"
    fi

    if [[ ${result} -eq 0 ]]  && [[ ${code} == 200 ]]
    then
      msg=$(jq         --raw-output .message     /tmp/sign_${HOSTNAME}.json 2> /dev/null)
      master_name=$(jq --raw-output .master_name /tmp/sign_${HOSTNAME}.json 2> /dev/null)
      master_ip=$(jq   --raw-output .master_ip   /tmp/sign_${HOSTNAME}.json 2> /dev/null)

      if [[ "${master_name}" = null ]] || [[ "${master_ip}" = null ]]
      then
        log_error "${msg}"
        log_error "no valid data were transmitted by our icinga2 master."

        exit 1
      fi

      mv /tmp/sign_${HOSTNAME}.json ${ICINGA2_LIB_DIRECTORY}/backup/

      log_info "${msg}"
      if [[ "${DEBUG}" = "true" ]]
      then
        log_debug "  - ${master_name}"
        log_debug "  - ${master_ip}"
      fi

      sleep 5s

      RESTART_NEEDED="true"
    else
      status=$(echo "${code}" | jq --raw-output .status 2> /dev/null)
      msg=$(echo "${code}" | jq --raw-output .message 2> /dev/null)

      [[ "${DEBUG}" = "true" ]] && log_debug "${status}"

      log_error "curl result: '${result}'"
      log_error "${msg}"

      # TODO
      # wat nu?
    fi

    endpoint_configuration
  fi
}
