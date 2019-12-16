#
#
#

# a satellite or agent don't need this
#
[[ "${ICINGA2_TYPE}" != "Master" ]] && return

# configure the ssmtp tool to create notification emails
#
configure_msmtp() {

  file=/etc/msmtprc

  cat << EOF > ${file}

defaults
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /var/log/msmtp.log

account ${ICINGA2_MSMTP_ACC_NAME}
host ${ICINGA2_MSMTP_RELAY_SERVER}
port 587


EOF

  if ( [[ ! -z "${ICINGA2_MSMTP_RELAY_USE_STARTTLS}" ]] && [[ "${ICINGA2_MSMTP_RELAY_USE_STARTTLS}" = "true" ]] )
  then
    cat << EOF >> ${file}
EOF
  fi

  if ( [[ ! -z ${ICINGA2_MSMTP_SMTPAUTH_USER} ]] && [[ ! -z ${ICINGA2_MSMTP_SMTPAUTH_PASS} ]] )
  then
    cat << EOF >> ${file}
auth on
user ${ICINGA2_MSMTP_SMTPAUTH_USER}
password ${ICINGA2_MSMTP_SMTPAUTH_PASS}
from ${ICINGA2_MSMTP_REWRITE_DOMAIN}

account default : ${ICINGA2_MSMTP_ACC_NAME}
EOF
  fi
}

create_smtp_aliases() {

  file=/etc/aliases

  [[ -f ${file} ]] && mv ${file} ${file}-SAVE

  # our default mail-sender
  #
  cat << EOF > ${file}
root: ${ICINGA2_MSMTP_RECV_ROOT}
EOF


  if [[ -n "${ICINGA2_MSMTP_ALIASES}" ]]
  then
    aliases=$(echo ${ICINGA2_MSMTP_ALIASES} | sed -e 's/,/ /g' -e 's/\s+/\n/g' | uniq)

    if [[ ! -z "${aliases}" ]]
    then
      # add more aliases
      #
      for u in ${aliases}
      do
        local=$(echo "${u}" | cut -d: -f1)
        email=$(echo "${u}" | cut -d: -f2)

        cat << EOF >> ${file}
${local}:${email}:${ICINGA2_MSMTP_RELAY_SERVER}
EOF
      done
    fi

  fi
}

configure_msmtp
create_smtp_aliases

# EOF
