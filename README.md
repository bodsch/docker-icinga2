docker-icinga2
==============

Installs an working icinga2 Core or Satellite based on alpine-linux

# Status
[![Build Status](https://travis-ci.org/bodsch/docker-icinga2.svg?branch=master)](https://travis-ci.org/bodsch/docker-icinga2)

# Build

# Docker Hub

You can find the Container also at  [DockerHub](https://hub.docker.com/r/bodsch/docker-icinga2/)

# supported Environment Vars

for MySQL Support:

  - MYSQL_HOST
  - MYSQL_PORT  (default: 3306)
  - MYSQL_ROOT_USER  (default: root)
  - MYSQL_ROOT_PASS  (default: '')
  - IDO_DATABASE_NAME  (default: icinga2core)
  - IDO_PASSWORD

for graphite Support:

  - CARBON_HOST
  - CARBON_PORT  (default: 2003)

for dashing Support:

  - DASHING_API_USER  (optional)
  - DASHING_API_PASS  (optional)
