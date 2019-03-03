
start_icinga() {

  exec /usr/sbin/icinga2 \
    daemon \
    --log-level debug
}


kill_icinga() {
  log_warn "headshot ..."
  pid=$(ps ax | grep icinga2 | grep -v grep | grep daemon | awk '{print $1}')
  [[ $(echo -e "${pid}" | wc -w) -gt 0 ]] && killall --verbose --signal HUP icinga2 > /dev/null 2> /dev/null
}
