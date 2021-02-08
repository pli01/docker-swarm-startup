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

export deploy_account=${deploy_account:-debian}
mkdir -p /home/$deploy_account/.ssh
echo "$deploy_ssh_private_key" | base64 -d > /home/$deploy_account/.ssh/id_rsa
chmod 0600 /home/$deploy_account/.ssh/id_rsa
echo "$deploy_ssh_public_key" | base64 -d > /home/$deploy_account/.ssh/id_rsa.pub
chmod 0600 /home/$deploy_account/.ssh/id_rsa.pub
echo "$deploy_ssh_public_key" | base64 -d >> /home/$deploy_account/.ssh/authorized_keys
chown -R $deploy_account. /home/$deploy_account/.ssh

