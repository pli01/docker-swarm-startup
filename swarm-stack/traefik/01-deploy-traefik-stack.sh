docker login privateregistry
docker stack deploy --compose-file=traefik-stack.yml --with-registry-auth traefik
