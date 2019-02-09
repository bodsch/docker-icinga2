#!/bin/bash

set -e

HADOLINT_VERSION='1.9.0'
HADOLINT_PATH='/usr/local/bin/hadolint'
if ! [ -x "$(command -v hadolint)" ]; then
  sudo wget -O "${HADOLINT_PATH}" "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64"
  sudo chmod +x "${HADOLINT_PATH}"
fi

hadolint Dockerfile.base
hadolint Dockerfile.master
hadolint Dockerfile.satellite
# shellcheck rootfs/init/run.sh -x
