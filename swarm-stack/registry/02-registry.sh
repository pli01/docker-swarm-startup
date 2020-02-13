docker run -d -p 5000:5000 \
  -v $(pwd)/conf/auth/users.htpasswd:/opt/registry/auth/users.htpasswd \
   -e "HTTP_PROXY=$http_proxy" \
   -e "HTTPS_PROXY=$https_proxy" \
   -e "NO_PROXY=$no_proxy" \
   -e "REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io" \
   --name registry ${REGISTRY_URL}/registry:2

