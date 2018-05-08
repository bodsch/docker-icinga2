# build from sources


A docker container with icinga2 and monitoring plugins based on [alpine-linux](https://www.alpinelinux.org/about/).

[Icinga2](https://www.icinga.com/products/icinga-2/) and the [monitoring plugins](https://www.monitoring-plugins.org/) are built from source code.

Since Icinga version 2.8.2 there are unfortunately problems with the musl library, which can lead to seg-faults with strong accesses via the API.
For this reason I have discontinued the support of this build.
