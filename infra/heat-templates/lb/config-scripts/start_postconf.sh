#!/bin/bash
echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -xe -o pipefail
function clean() {
[ "$?" -gt 0 ] && notify_failure "Deploy $0: $?"
}
trap clean EXIT QUIT KILL

libdir=/home/debian
[ -f ${libdir}/common_functions.sh ] && source ${libdir}/common_functions.sh

ret=0
# add authorized_keys (better use cloud-init)
echo "## add authorized_keys"
apt-get -q update
apt-get -qy install jq
HOME=/home/debian
if [ ! -d $HOME/.ssh ] ; then mkdir -p $HOME/.ssh ; fi
echo '$ssh_authorized_keys' |  jq -r ".[]" >> $HOME/.ssh/authorized_keys
chown debian. -R $HOME/.ssh
exit $ret

