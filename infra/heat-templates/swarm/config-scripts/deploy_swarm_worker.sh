#!/bin/bash
echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -xe -o pipefail
function clean() {
ret=$?
[ "$ret" -gt 0 ] && notify_failure "Deploy $0: $?"
exit $ret
}
trap clean EXIT QUIT KILL

libdir=/home/debian
[ -f ${libdir}/common_functions.sh ] && source ${libdir}/common_functions.sh

echo "## configuration swarm master" 

## parameters
no_proxy=$no_proxy
registry_ip=$registry_ip
http_proxy=$http_proxy
dns_nameservers='$dns_nameservers'
dns_domainname='$dns_domainname'
swarm_token='$swarm_token'
swarm_leader='$swarm_leader'

PACKAGE_CUSTOM="apt-transport-https \
     ca-certificates \
     curl \
     gnupg2 \
     software-properties-common"

apt-get -q update       && apt-get install -qy --no-install-recommends sudo curl         $PACKAGE_CUSTOM

cd /root
cat <<EOF > build.sh
registry_ip=${registry_ip}
EOF
cat <<'EOF' >> build.sh
REGISTRY_URL=$registry_ip
REPOSITORY_URL=http://${REGISTRY_URL}/nexus/repository/modules-docker/
export REPOSITORY_URL REGISTRY_URL
# build params
MIRROR_DEBIAN=http://${REGISTRY_URL}/nexus/repository
MIRROR_DOCKER=http://${REGISTRY_URL}/nexus/repository/docker-project/linux
MIRROR_DOCKER_COMPOSE=http://${REGISTRY_URL}/nexus/repository/docker-compose
PYPI_URL=http://${REGISTRY_URL}/nexus/repository/pypi/simple
PYPI_HOST=${REGISTRY_URL}
RUBY_URL=http://${REGISTRY_URL}/nexus/repository/rubygems/
export MIRROR_DEBIAN MIRROR_DOCKER MIRROR_DOCKER_COMPOSE PYPI_URL PYPI_HOST RUBY_URL

NPM_REGISTRY=http://${REGISTRY_URL}/nexus/repository/npm-proxy/
SASS_REGISTRY=http://${REGISTRY_URL}/nexus/repository/node-sass/download/
CYPRESS_DOWNLOAD_MIRROR=http://${REGISTRY_URL}/nexus/repository/cypress/
export NPM_REGISTRY SASS_REGISTRY CYPRESS_DOWNLOAD_MIRROR
EOF

cat <<EOF > proxy.sh
#export https_proxy=${http_proxy}
#export http_proxy=${http_proxy}
#export no_proxy=localhost,${no_proxy}
# dns_nameservers=${dns_nameservers}
# dns_domainname=${dns_domainname}
EOF

source build.sh
source proxy.sh

# config docker proxy
cat <<EOF > /etc/docker/daemon.json
{
    "data-root": "/DATA/docker",
    "dns": ${dns_nameservers},
    "dns-search": ${dns_domainname},
    "insecure-registries": [
        "localhost.local",
        "${registry_ip}"
    ],
    "registry-mirrors": [
        "http://${registry_ip}"
    ],
    "log-driver": "journald",
    "mtu": 1450
}
EOF

# config docker http proxy (http_proxy = celui du master)
ENABLE_HTTP_PROXY=true
if [ -n "$ENABLE_HTTP_PROXY" ] ; then
mkdir -p /etc/systemd/system/docker.service.d/
cat <<EOF > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=${http_proxy}"
Environment="HTTPS_PROXY=${http_proxy}"
Environment="NO_PROXY=localhost,127.0.0.1,${no_proxy}"
EOF
fi

# get engine specs (availability-zone,instance-type)
availability_zone="$(wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone)"
instance_type="$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-type)"

echo "# config /etc/docker/daemon.json"
if [ -d /etc/docker ] ;then
  docker_daemon_conf='{}'
  if [ -f /etc/docker/daemon.json ] ; then
   cat /etc/docker/daemon.json > /etc/docker/daemon.json.orig
   docker_daemon_conf="$(cat /etc/docker/daemon.json)"
  fi
  if [ ! -z "$docker_daemon_conf" ] ; then
  echo "$docker_daemon_conf" | \
    jq --arg driver journald \
       --argjson labels '["availability-zone='$availability_zone'", "instance-type='$instance_type'"]' '. + { "log-driver": $driver } + { "labels": $labels }' \
        > /etc/docker/daemon.json
  fi
  systemctl daemon-reload
  service docker restart
fi


# ulimit
cat <<EOF > /etc/security/limits.d/debian.conf
debian soft nofile 4096
debian hard nofile 8192
debian soft nproc 30654
debian hard nproc 30654
EOF

# grep ^Client  /etc/ssh/sshd_config
sed -i.orig -e 's/^ClientAliveInterval.*/ClientAliveInterval 15/g ; s/^ClientAliveCountMax.*/ClientAliveCountMax 10/g ' /etc/ssh/sshd_config
service ssh restart


#
# install pre build docker image
#

su - debian <<EOF
cat <<EOPROXY > /home/debian/proxy.sh
export https_proxy=${http_proxy}
export http_proxy=${http_proxy}
export no_proxy=localhost,${no_proxy}
EOPROXY

cat <<EOFSWARM > /home/debian/swarm.sh
export swarm_token=${swarm_token}
export swarm_leader=${swarm_leader}
EOFSWARM

EOF

su - debian <<'EOF'
cat <<'EOFMASTER' > /home/debian/deploy.sh
#!/bin/bash
set -ex
libdir=/home/debian
[ -f ${libdir}/common_functions.sh ] && source ${libdir}/common_functions.sh
[ -f ${libdir}/swarm.sh ] && source ${libdir}/swarm.sh

timeout=10
test_result=1
until [ "$timeout" -le 0 -o "$test_result" -eq "0" ] ; do
  set +e
  local_ip=$(curl -s --fail  http://169.254.169.254/latest/meta-data/local-ipv4)
  test_result=$?
 echo "Wait $timeout seconds: $test_result";
 (( timeout-- ))
 sleep 1
done
set -e
if  [ -z "$local_ip" ] || [ "$test_result" -gt 0 ] ; then
        echo "ERREUR"
        exit $test_result
fi
# leader
# manager
# worker
echo "#worker $local_ip ok"
docker swarm join --listen-addr $local_ip:2377 --advertise-addr $local_ip --token $swarm_token $swarm_leader
EOFMASTER
EOF

# Deploy
su - debian <<'EOF'
time bash deploy.sh
EOF

ret=$?

if [ "$ret" -gt 0 ] ;then
  notify_failure "Start master failed ($ret)"
fi
exit $ret

