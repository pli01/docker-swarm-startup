docker login privateregistry
docker stack deploy --compose-file=web-stack.yml --with-registry-auth web
