docker login privateregistry
docker config create haproxy-web haproxy.cfg
docker stack deploy --compose-file=haproxy-stack.yml --with-registry-auth haproxy
