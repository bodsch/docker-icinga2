docker-icinga2
==============

Installs an working icinga2 Core based on alpine-linux

# Status
[![Build Status](https://travis-ci.org/bodsch/docker-icinga2.svg?branch=master)](https://travis-ci.org/bodsch/docker-icinga2)

# Build

# Docker Hub

You can find the Container also at  [DockerHub](https://hub.docker.com/r/bodsch/docker-icinga2/)

# supported Environment Vars

for MySQL Support:

  - MYSQL_HOST
  - MYSQL_PORT
  - MYSQL_ROOT_USER
  - MYSQL_ROOT_PASS
  - IDO_PASSWORD

for graphite Support:

  - CARBON_HOST
  - CARBON_PORT

for dashing Support:

  - DASHING_API_USER
  - DASHING_API_PASS
