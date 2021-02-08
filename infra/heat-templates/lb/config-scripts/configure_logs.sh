#!/bin/bash
echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -xe -o pipefail
function clean() {
[ "$?" -gt 0 ] && notify_failure "Deploy $0: $?"
}
trap clean EXIT QUIT KILL

libdir=/home/debian
[ -f ${libdir}/common_functions.sh ] && source ${libdir}/common_functions.sh

echo "## configuration logs" 

echo "# config /etc/rsyslog.conf"
sed -i.back  -e 's|^module(load="imuxsock".*|module(load="imuxsock" SysSock.Use="off" SysSock.Name="/run/systemd/journal/syslog")|g'  /etc/rsyslog.conf
echo "# config /etc/rsyslog.d"

cat <<'EOF' > /etc/rsyslog.d/01-journald-json.conf
# read journald, only last messages
module(load="imjournal" IgnorePreviousMessages="on")
# If the message contains json, parse it.
module(load="mmjsonparse")

# create structured json with selected fields (journald message with key MESSAGE)
template(
  name="json_docker"
  type="list"
  option.casesensitive="on"
) {
    constant(value="{")
      constant(value="\"@timestamp\":\"")        property(name="timereported" dateFormat="rfc3339" date.inUTC="on")
      constant(value="\",\"@version\":\"1")
      constant(value="\",\"message\":\"")     property(name="$!MESSAGE" format="json")
      constant(value="\",\"hostname\":\"")    property(name="hostname")
      constant(value="\",\"severity\":\"")    property(name="syslogseverity-text")
      constant(value="\",\"facility\":\"")    property(name="syslogfacility-text")
      constant(value="\",\"programname\":\"") property(name="programname")
      constant(value="\",\"procid\":\"")      property(name="procid")
      constant(value="\",\"container_id\":\"")   property(name="$!CONTAINER_ID")
      constant(value="\",\"container_name\":\"") property(name="$!CONTAINER_NAME")
      constant(value="\",\"container_tag\":\"")  property(name="$!CONTAINER_TAG")
      constant(value="\"}\n")
#      constant(value="\",")                      property(name="$!json" position.from="2")
#    constant(value="\n")
}

action(type="mmjsonparse" cookie="" container="!json")
EOF

cat <<'EOF' > /etc/rsyslog.d/02-json-template.conf
# create structured json with selected fields (message with key msg)
template(
  name="json-template"
  type="list"
) {
    constant(value="{")
      constant(value="\"@timestamp\":\"")     property(name="timereported" dateFormat="rfc3339" date.inUTC="on")
      constant(value="\",\"@version\":\"1")
      constant(value="\",\"message\":\"")     property(name="msg" format="json")
      constant(value="\",\"hostname\":\"")    property(name="hostname")
      constant(value="\",\"severity\":\"")    property(name="syslogseverity-text")
      constant(value="\",\"facility\":\"")    property(name="syslogfacility-text")
      constant(value="\",\"programname\":\"") property(name="programname")
      constant(value="\",\"procid\":\"")      property(name="procid")
      constant(value="\"}\n")
}
EOF

echo "# send to $syslog_relay"
if [ ! -z "$syslog_relay" ] ; then

  cat <<'EOF' > /etc/rsyslog.d/99-forward-elk.conf
# log contains variable MESSAGE go in json format to elk asis
if ($!MESSAGE != "") then {
*.* @$syslog_relay:514;json_docker
}
EOF

  echo "# config /etc/rsyslog.d/49-haproxy.conf"
  if SYSTEMD_PAGER='' service haproxy status ;then
  cat <<'EOF' > /etc/rsyslog.d/49-haproxy.conf
# Create an additional socket in haproxy's chroot in order to allow logging via
# /dev/log to chroot'ed HAProxy processes
$AddUnixListenSocket /var/lib/haproxy/dev/log

# Send HAProxy messages to a dedicated logfile
if $programname startswith 'haproxy' then /var/log/haproxy.log
if $programname startswith 'haproxy' then @$syslog_relay:514;json-template
&~
EOF
  fi
fi

service rsyslog restart

if SYSTEMD_PAGER='' service docker status ; then
echo "# config /etc/docker/daemon.json"
cat <<'EOF' > /etc/docker/daemon.json
{ "log-driver": "journald" }
EOF
service docker restart
fi

echo "# config logrotate"
cat <<EOF > /etc/logrotate.d/rsyslog
# Local modifications will be overwritten.
/var/log/mail.info /var/log/mail.warn /var/log/mail.err /var/log/mail.log /var/log/daemon.log /var/log/kern.log /var/log/auth.log /var/log/user.log /var/log/lpr.log /var/log/cron.log /var/log/debug /var/log/messages {
  rotate 4
  hourly
  size 10M
  missingok
  notifempty
  compress
  delaycompress
  sharedscripts
  postrotate
    invoke-rc.d rsyslog rotate > /dev/null
  endscript
}
EOF

cat <<EOF > /etc/logrotate.d/syslog
# Local modifications will be overwritten.
/var/log/syslog {
  rotate 7
  hourly
  size 10M
  missingok
  notifempty
  compress
  delaycompress
  postrotate
    invoke-rc.d rsyslog rotate > /dev/null
  endscript
}
EOF

exit 0
