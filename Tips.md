## bastion
```
Host 172.16.1?.*
   StrictHostKeyChecking no
   UserKnownHostsFile=/dev/null
```
## manager
### list swarm cluster
```
docker node ls -q | while read a ; do docker node inspect --format '{{ .Description.Hostname  }} {{ .Status.Addr}} {{ .Status.State }} {{ .Spec.Availability }} {{.Spec.Role }}' $a ; done
```
### clean Down nodes
```
docker node rm $(docker node ls -f role=worker -f role=manager |grep Down | awk ' { print $1 }')
```

## portainer on manager/leader
### prereq

* portainer
```
docker pull portainer/portainer:latest
docker pull portainer/agent:latest
docker tag portainer/portainer:latest privateregistry/portainer/portainer:latest
docker tag portainer/agent:latest privateregistry/portainer/agent:latest
docker login privateregistry
docker push privateregistry/portainer/portainer
docker push privateregistry/portainer/agent
```

* haproxy
```
docker pull haproxytech/haproxy-debian:2.0
docker tag  haproxytech/haproxy-debian:2.0 privateregistry/haproxytech/haproxy-debian:2.0
docker push privateregistry/haproxytech/haproxy-debian:2.0
```

* nginxdemos/hello
```
docker pull nginxdemos/hello
docker tag  nginxdemos/hello privateregistry/nginxdemos/hello
docker push privateregistry/nginxdemos/hello
```

### portainer deployement
```
docker node update --label-add leader=true swarm-leader-test-leader-0
docker node update --availability active swarm-leader-test-leader-0

docker login privateregistry
curl -L https://downloads.portainer.io/portainer-agent-stack.yml -o portainer-agent-stack.yml
change port 80:9000 and image registry
docker stack deploy --compose-file=portainer-agent-stack.yml --with-registry-auth portainer
docker node update --availability pause swarm-leader-test-leader-0
docker node update --availability active swarm-manager-test-manager-0
docker node update --availability active swarm-manager-test-manager-1
```

## create app network
```
docker network create --opt com.docker.network.driver.mtu=1450  --driver overlay app-network
```

## LB router: haproxy + config
```
docker login privateregistry
docker config create haproxy-web haproxy.cfg
docker stack deploy --compose-file=haproxy.yml --with-registry-auth haproxy
```

## web stack deployment
```
docker login privateregistry
docker stack deploy --compose-file=web.yml --with-registry-auth web
```
###  alternative: web app with 3 replica
```
docker login privateregistry
docker service create --with-registry-auth --replicas 3 -p 80:80 --name web privateregistry/nginxdemos/hello
```

###  alternative: web app on all cluster node
```
docker service create --with-registry-auth --mode global -p 80:80 --name web privateregistry/nginxdemos/hello
```

