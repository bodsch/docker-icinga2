
start_icinga() {

  exec /usr/sbin/icinga2 \
    daemon \
      --config /etc/icinga2/icinga2.conf \
      --errorlog /dev/stdout
}


kill_icinga() {
  log_warn "headshot ..."
  icinga_pid=$(ps ax | grep icinga2 | grep -v grep | awk '{print $1}')
  [[ -z "${icinga_pid}" ]] || killall icinga2 > /dev/null 2> /dev/null
}
