mkdir -p conf/auth
docker run --entrypoint htpasswd  registry:2 -Bbn testuser testpassword > conf/auth/users.htpasswd
docker config create registry-auth-htpasswd conf/auth/users.htpasswd
