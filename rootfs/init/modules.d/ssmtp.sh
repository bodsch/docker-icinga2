#
#
#

# a satellite or agent don't need this
#
[[ "${ICINGA2_TYPE}" != "Master" ]] && return

# configure the ssmtp tool to create notification emails
#
configure_ssmtp() {

  file=/etc/ssmtp/ssmtp.conf

  cat << EOF > ${file}

# ssmtp.conf
# Benutzer, der alle Mails bekommt, die an Benutzer mit einer ID < 1000 adressiert sind.
root=postmaster
# Überschreiben der Absender-Domain.
rewriteDomain=${ICINGA2_SSMTP_REWRITE_DOMAIN}
# the mailrelay
mailhub=${ICINGA2_SSMTP_RELAY_SERVER}
FromLineOverride=NO
EOF

  if ( [[ ! -z "${ICINGA2_SSMTP_RELAY_USE_STARTTLS}" ]] && [[ "${ICINGA2_SSMTP_RELAY_USE_STARTTLS}" = "true" ]] )
  then
    cat << EOF >> ${file}
UseSTARTTLS=YES
EOF
  fi

  if ( [[ ! -z ${ICINGA2_SSMTP_SMTPAUTH_USER} ]] && [[ ! -z ${ICINGA2_SSMTP_SMTPAUTH_PASS} ]] )
  then
    cat << EOF >> ${file}
AuthUser=${ICINGA2_SSMTP_SMTPAUTH_USER}
AuthPass=${ICINGA2_SSMTP_SMTPAUTH_PASS}
EOF
  fi
}

create_smtp_aliases() {

  file=/etc/ssmtp/revaliases

  [[ -f ${file} ]] && mv ${file} ${file}-SAVE

  # our default mail-sender
  #
  cat << EOF > ${file}
root:${ICINGA2_SSMTP_SENDER_EMAIL}@${ICINGA2_SSMTP_REWRITE_DOMAIN}:${ICINGA2_SSMTP_RELAY_SERVER}
EOF


  if [[ -n "${ICINGA2_SSMTP_ALIASES}" ]]
  then
    aliases=$(echo ${ICINGA2_SSMTP_ALIASES} | sed -e 's/,/ /g' -e 's/\s+/\n/g' | uniq)

    if [[ ! -z "${aliases}" ]]
    then
      # add more aliases
      #
      for u in ${aliases}
      do
        local=$(echo "${u}" | cut -d: -f1)
        email=$(echo "${u}" | cut -d: -f2)

        cat << EOF >> ${file}
${local}:${email}:${ICINGA2_SSMTP_RELAY_SERVER}
EOF
      done
    fi

  fi
}

configure_ssmtp
create_smtp_aliases

# EOF
