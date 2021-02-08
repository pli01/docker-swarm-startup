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
echo "## http-proxy configuration"
export no_proxy=$no_proxy
export tinyproxy_upstream=$tinyproxy_upstream
export tinyproxy_no_upstream=$tinyproxy_no_upstream
export tinyproxy_proxy_authorization=$tinyproxy_proxy_authorization

echo "## installation des pre-requis"
apt-get -q update
apt-get -qy install curl jq tinyproxy

# add authorized_keys (better use cloud-init)
echo "## add authorized_keys"
HOME=/home/debian
if [ ! -d $HOME/.ssh ] ; then mkdir -p $HOME/.ssh ; fi
echo '$ssh_authorized_keys' |  jq -r ".[]" >> $HOME/.ssh/authorized_keys
echo "$deploy_ssh_public_key" | base64 -d >> $HOME/.ssh/authorized_keys
chown debian. -R $HOME/.ssh
HOME=/root

# # tinyproxy
cp /etc/tinyproxy/tinyproxy.conf /etc/tinyproxy/tinyproxy.conf.orig
cat <<EOF > /etc/tinyproxy/tinyproxy.conf
User tinyproxy
Group tinyproxy
Port 8888
Timeout 600
DefaultErrorFile "/usr/share/tinyproxy/default.html"
StatFile "/usr/share/tinyproxy/stats.html"
Logfile "/var/log/tinyproxy/tinyproxy.log"
LogLevel Info
PidFile "/run/tinyproxy/tinyproxy.pid"
MaxClients 100
MinSpareServers 5
MaxSpareServers 20
StartServers 10
MaxRequestsPerChild 0
ViaProxyName "tinyproxy"
ConnectPort 443
ConnectPort 563
$( [ -z "${tinyproxy_proxy_authorization}" ] && echo "# Proxy-Autorization disable" || echo "AddHeader \"Proxy-Authorization\" \"Basic ${tinyproxy_proxy_authorization}\"" )
$( [ -z "${tinyproxy_no_upstream}" ] && echo "# no upstream disable" || echo "no upstream \"${tinyproxy_no_upstream}\"" )
$( [ -z "${tinyproxy_upstream}" ] && echo "# upstream disable" || echo "upstream ${tinyproxy_upstream}" )
Allow 127.0.0.1
$(ip add |grep "inet " |awk ' { print "Allow",$2 } ')
EOF
service tinyproxy restart

echo "## Fin post installation"

echo "## Post check"
echo "# end postconf http-proxy"

[ "$ret" -gt 0 ] && notify_failure "Start http-proxy failed ($ret)"
[ "$ret" -eq 0 ] && notify_success "Start http-proxy success ($ret)"
