docker network create --opt com.docker.network.driver.mtu=1450  --driver overlay traefik-network
docker login privateregistry
docker stack deploy --compose-file=traefik-stack.yml --with-registry-auth traefik
