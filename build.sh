#!/bin/bash

. config.rc

echo "build container '${TAG_NAME}'"

docker build --tag=${TAG_NAME} .
