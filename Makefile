export GIT_SHA1          := $(shell git rev-parse --short HEAD)
export DOCKER_IMAGE_NAME := icinga2
export DOCKER_NAME_SPACE := ${USER}
export DOCKER_VERSION    ?= latest
export BUILD_DATE        := $(shell date +%Y-%m-%d)
export BUILD_VERSION     := $(shell date +%y%m)
export BUILD_TYPE        ?= stable
export ICINGA2_VERSION   ?= 2.10.2
export CERT_SERVICE_VERSION ?= 0.18.3


.PHONY: build shell run exec start stop clean

default: build

build:
	@hooks/build

master-shell:
	@hooks/shell master

satellite-shell:
	@hooks/shell satellite

run:
	@hooks/run

exec:
	@hooks/exec

start:
	@hooks/start

stop:
	@hooks/stop

clean:
	@hooks/clean

compose-file:
	@hooks/compose-file

linter:
	@tests/linter.sh

integration_test:
	@tests/integration_test.sh

test: linter integration_test
