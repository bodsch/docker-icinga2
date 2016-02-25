#!/bin/bash

. config.rc

docker build --tag=${TAG_NAME} .
