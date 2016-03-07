#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

# ---------------------------------------------------------------------------------------

# docker run \
#   --interactive \
#   --tty \
#   --publish=5665:5665 \
#   --publish=6666:6666 \
#   --dns=172.17.0.1 \
#   --hostname=${USER}-${TYPE} \
#   --name ${CONTAINER_NAME} \
#   ${TAG_NAME}

set -e

sudo docker run \
  --tty=false \
  --interactive=false \
  --publish=5665:5665 \
  --publish=6666:6666 \
  --volume=${PWD}/share/icinga2:/usr/local/monitoring \
  --link=${USER}-mysql:database \
  --env MYSQL_HOST=database \
  --env MYSQL_PORT=3306 \
  --env MYSQL_USER=root \
  --env MYSQL_PASS=foo.bar.Z \
  --env IDO_PASSWORD=xxxxxxxxx \
  --env CARBON_HOST=${USER}-graphite.docker \
  --env CARBON_PORT=2003 \
  --dns=172.17.0.1 \
  --hostname=${USER}-${TYPE} \
  --name ${CONTAINER_NAME} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF
