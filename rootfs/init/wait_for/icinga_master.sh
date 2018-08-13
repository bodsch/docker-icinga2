
# wait for the Icinga2 Master
#
wait_for_icinga_master() {

  # I can't wait for myself.
  #
  [[ "${ICINGA2_TYPE}" = "Master" ]] && return

  . /init/wait_for/dns.sh
  . /init/wait_for/port.sh

  wait_for_dns ${ICINGA2_MASTER}
  wait_for_port ${ICINGA2_MASTER} 5665 50

  # log_info "Waiting for icinga2 master on host '${ICINGA2_MASTER}' to come up"

  sleep 5s
}

wait_for_icinga_master
