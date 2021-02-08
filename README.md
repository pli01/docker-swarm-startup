# docker-swarm-startup

## Cluster Swarm + portainer + traefik|haproxy + webdemo
* Ready to use swarm cluster
* cluster swarm structure: leader+managers+workers
* swarm stack portainer (swarm management UI)
* swarm stack LB router to route traffic to internal container (portainer, LB(traefik,haproxy) , LBstats, and APP)
* swarm stack demo web
* external Reverse Proxy (nginx) in front of swarm LB router (traefik,haproxy)

[docs/swarm-startup-swarm-container-network.png](docs/swarm-startup-swarm-container-network.png)

## Infra Provisionning

* Based on openstack
* Ready to use swarm cluster
* Scale up&down workers with http POST autoscaling url
* Deploy with makefile + simple scripts
* Openstack heat templates per resource/autoscaling group (1 leader, 3 managers, N workers per AZ, bastion, http_proxy)
* AutoJoin swarm manager/worker at bootstrap
* Deploy infra swarm stack (portainer,traefik)

### openstack topology
* 1 stack bastion: SSH
* 1 stack http proxy for outgoing traffic
* 3 stacks with persistant FIP : bastion-FIP, leader-FIP(1), managers-FIP (2)
* 1 stacks with persistant Data Volume : leader-data(1)
* 1 stack leader
  * ResourceGroup : 1 instance + 1 FIP + persistant data volume (raft/backup)
* 1 stack manager:
  * ResourceGroup per AZ : 1 instance + 1 FIP
* 3 stack workers per AZ , anti-affinity:
  * AutoScalingGroup : min 0,1,max n instances

* Add external (nginx) Reverse Proxy to route trafic to portainer/traefik UI and web or app (for demo)

[docs/swarm-startup-swarm-cluster-openstack.png](docs/swarm-startup-swarm-cluster-openstack.png)

### swarm cluster topology
* 1 leader
  * portainer stack
  * portainer agent stack
* 3 managers per Availibility Zone
  * portainer agent stack
  * traefik stack (published port, ingress network)
* n workers per Availibility Zone
  * portainer agent stack
  * web stack
  * app stack

### prereq

* Push infra docker images (portainer,traefik, nginx demo..) to private docker registry (or Swift Object) before deployment
