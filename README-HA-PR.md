# Icinga2 HA Setup Pull Request

The existing Codebase was modified to meet the need of an HA Setup for Icinga2. This was done by consulting the 
Icinga2 Documentation and take the advice from there. Some of the needed changes will be documented here.

## Prerequisites

The Setup was build / tested with an Docker Swarm Cluster and the following components:
- MariaDB Galera Cluster with 3 Nodes for Failover
- Traefik for Reverse Proxy
- 2 Icinga2 Instances with DNS pointing to the Icinga2 FQDN and port 5665 exposed on the running node(s)

Make sure that the Master Instance can be reached by it's DNS Name on Port 5665. Independent if it's a docker service name
or a real DNS Name. 

## Dockerfile modifications

Icinga2 is not using conf.d Files for Cluster setups. Therefore the default definitions are moved to global templates folder and afterwards removed. Otherwise HA CLuster sync isn't working properly:

- mv /etc/icinga2/conf.d/{commands,groups,notifications,templates}.conf /etc/icinga2/zones.d/global-templates
- rm -rf /etc/icinga2/conf.d/*

## Values to modify


### MULTI_MASTER

The default value is "false" to not break single instances and to not confuse. It is believed that the value will only be true after
you have read this readme and understand consequences of this choice.

If you set this value to true, also the following parameters need to be adjusted / set:

| Environmental Variable             | Default Value        	| Description                                                     |
| :--------------------------------- | :-------------      		| :-----------                                                    |
| `MULTI_MASTER`               		 | false                	| Activate Icinga2 HA Setup 									  |
| `MYSQL_IDO_HA`               		 | false                	| see next note!			 									  |
| `HA_CONFIG_MASTER`                 | false                	| Set Node  authoritative or not. Set only on 1 Instance to true  |
| `HA_MASTER1`	                     | -                    	| Master 1 of the HA Setup. Can be same value on both		      |
| `HA_MASTER1_DNS`	                 | $(dig $HA_MASTER1 +short)| Recursive Lookup of DNS Name. Only if HA_MASTER1_IP isn't set   |
| `HA_MASTER1_IP`	                 | ${HA_MASTER1_DNS}}      	| Allow override of Master IP 								      |
| `HA_MASTER2`	                     | -                    	| Master 2 of the HA Setup. Can be same value on both		      |
| `HA_MASTER2_DNS`	                 | $(dig $HA_MASTER2 +short)| Recursive Lookup of DNS Name. Only if HA_MASTER2_IP isn't set   |
| `HA_MASTER2_IP`	                 | ${HA_MASTER2_DNS}}      	| Allow override of Master IP 								      |

By default itÄs enough to set `HA_MASTER1` and `HA_MASTER1` as the Startup Script will figure out the IP by dns lookup and set this 
in the zones conf at every start. Even Dynamic IPs aren't a problem with this.

#### MYSQL_IDO_HA

This Value needs to be set to true on both instances if you write to on central MySQL replicated Cluster in the compose files and reflects to "enable_ha" of the IdoMySqlConnection. If the instances write to their own DB, leave this set to false.

https://icinga.com/docs/icinga2/latest/doc/09-object-types/#objecttype-idomysqlconnection