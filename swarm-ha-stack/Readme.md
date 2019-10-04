# Setup
Docker Swarm Cluster

# Galera Cluster
Galera Cluster was setup by using: https://github.com/colinmollenhour/mariadb-galera-swarm/tree/master/examples/swarm and declaring the network as 'galera_net'

# Hostpath bindings

Adapt path to fit your environment and precreate the folders:
```
mkdir -p /docker-data/{icinga2/var,icinga2/var/certs,icinga2/var/ca}
chown -R 101:101 /docker-data/icinga2
```

# Icinga2 Network

Explicitly declared as external so we can take both stacks independent offline if needed. Create with 'docker network create --driver=overlay icinga2_backend' or 'make network' from the Makefile.

# Placement Constraints

Update the constraints to reflect your environment. The Stacks can't be run on single Node cause of the Host binding of Port 5665.

# Deploy Master 1 

Create Master 1 and wait until it's up and ready.

# Deploy Master 2

Copy 'icinga2/var/certs/*',icinga2/var/ca/*' folders from the master1 node over to master2 Node. This step is needed so the masters use the same CA and the clients accept commands and checks from both. The path can vary if you modified it.