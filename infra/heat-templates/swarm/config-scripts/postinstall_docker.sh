#!/bin/bash
echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -xe -o pipefail
function clean() {
ret=$?
[ "$ret" -gt 0 ] && notify_failure "Deploy $0: $message ($ret)"
exit $ret
}
trap clean EXIT QUIT KILL

libdir=/home/debian
[ -f ${libdir}/common_functions.sh ] && source ${libdir}/common_functions.sh

# pre check
echo "# pre check"
wait_network_up

# postconf
echo "## docker configuration"

export no_proxy=$no_proxy
export http_proxy=$http_proxy
export https_proxy=$https_proxy

echo "## Installation et configuration de docker-ce"
echo "## installation des pre-requis"
apt-get update -q
apt-get -qy install libapparmor1 libltdl7 apt-transport-https ca-certificates curl software-properties-common jq

mkdir /home/debian/download
cd /home/debian/download

curl_args="--retry 5 --retry-delay 1 --retry-max-time 10 --fail"
docker_repo_url=$docker_repo_url
docker_repo_key=$docker_repo_key
docker_version=$docker_version
default_docker_repo_url=${docker_repo_url:-https://download.docker.com/linux/debian}
default_docker_repo_key=${docker_repo_key:-https://download.docker.com/linux/debian/gpg}
add-apt-repository "deb [arch=amd64] ${default_docker_repo_url} $(lsb_release -cs) stable"
curl $curl_args -fsSL ${default_docker_repo_key} | apt-key add -
apt-get update -q

echo "## disable nscld LDAP"
type -p nslcd && service nslcd stop
type -p nscd && service nscd stop

echo "## installation docker"
apt-get -qy install "docker-ce=${docker_version}"
echo "## ajout debian au groupe docker"
usermod -aG docker debian

systemctl daemon-reload
systemctl restart docker

echo "## enable nscld LDAP"
type -p nslcd && service nslcd start
type -p nscd && service nscd start
type -p nscd && nscd -i group

echo "## Installation de docker-compose"

#apt-get -y install docker-compose
wget -T 15 -w 2 --random-wait -L --no-check-certificate -O /usr/local/bin/docker-compose $artefact_url/$docker_compose_image
chmod +x /usr/local/bin/docker-compose

echo "## vm max_map_count"
sysctl -w vm.max_map_count=262144

# add authorized_keys (better use cloud-init)
echo "## add authorized_keys"
HOME=/home/debian
if [ ! -d $HOME/.ssh ] ; then mkdir -p $HOME/.ssh ; fi
echo '$ssh_authorized_keys' |  jq -r ".[]" >> $HOME/.ssh/authorized_keys
echo "$deploy_ssh_public_key" | base64 -d >> $HOME/.ssh/authorized_keys
chown debian. -R $HOME/.ssh
HOME=/root

echo "## Fin post installation"

echo "## Post check"
docker version || exit $?
docker-compose  version || exit $?
id debian  | grep '(docker)' || exit $?
#echo "## reboot du serveur"
# reboot
