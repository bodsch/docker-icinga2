#!/bin/bash

data=$(curl \
  --silent \
  --location \
  https://packages.icinga.com/debian/dists/icinga-jessie/main/binary-amd64/Packages)

echo -e "${data}" | \
  grep -E "^Package: icinga2-bin" -A 7 | \
  grep "Version: " | \
  sort --version-sort | \
  tail -n 1 | \
  sed -e 's|Version: ||' -e 's|-1.jessie||'



