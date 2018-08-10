
start_icinga() {

  exec /usr/sbin/icinga2 \
    daemon
}


kill_icinga() {
  log_warn "headshot ..."
  pid=$(ps ax | grep icinga2 | grep daemon | grep -v grep | awk '{print $1}')
  [[ -z "${pid}" ]] || killall icinga2 > /dev/null 2> /dev/null
}
