docker node update --label-add leader=true swarm-leader-test-leader-0
docker node update --availability active swarm-leader-test-leader-0
docker login privateregistry
docker stack deploy --compose-file=portainer-stack.yml --with-registry-auth portainer
docker node update --availability pause swarm-leader-test-leader-0

