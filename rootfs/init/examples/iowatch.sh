#!/bin/sh

sigint_handler() {

  pkill -15 $(cat /tmp/dnsmasq.pid)
  exit
}

trap sigint_handler SIGINT QUIT KILL

start() {

  touch /app/dnsmasq.addn.docker
  chmod a+rw /app/dnsmasq.addn.docker

  /usr/sbin/dnsmasq --user=root --pid-file=/tmp/dnsmasq.pid --log-facility=/tmp/dnsmasq.log
}

start

while true
do
  $@ &
  PID=$!
  inotifywait -e modify -e move -e create -e delete /app/dnsmasq.addn.docker

  pkill -HUP -P $(cat /tmp/dnsmasq.pid)
done


# EOF
