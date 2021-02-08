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

ret=0
# pre check
echo "# pre check"
wait_network_up

# postconf
echo "## bastion configuration"
export no_proxy=$no_proxy

echo "## installation des pre-requis"
apt-get update
apt-get -qy install curl jq

# add authorized_keys (better use cloud-init)
echo "## add authorized_keys"
HOME=/home/debian
if [ ! -d $HOME/.ssh ] ; then mkdir -p $HOME/.ssh ; fi
echo '$ssh_authorized_keys' |  jq -r ".[]" >> $HOME/.ssh/authorized_keys
chown debian. -R $HOME/.ssh
HOME=/root

# activation ssh forwarding
echo "## AllowTcpForwarding yes"
sed -i.orig -e 's/^AllowTcpForwarding.*//g; $a\AllowTcpForwarding yes' /etc/ssh/sshd_config
grep "^AllowTcpForwarding yes" /etc/ssh/sshd_config || exit 1

echo "## AllowAgentForwarding yes"
sed -i.orig -e 's/^AllowAgentForwarding*//g; $a\AllowAgentForwarding yes' /etc/ssh/sshd_config
grep "^AllowAgentForwarding yes" /etc/ssh/sshd_config || exit 1

service ssh restart
echo "## Fin post installation"

echo "## Post check"
echo "# end postconf bastion"

[ "$ret" -gt 0 ] && notify_failure "Start bastion failed ($ret)"
[ "$ret" -eq 0 ] && notify_success "Start bastion success ($ret)"
