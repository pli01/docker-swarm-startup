docker network create --opt com.docker.network.driver.mtu=1450  --driver overlay ci-network
docker login privateregistry
docker stack deploy --compose-file=ci-stack.yml --with-registry-auth ci
