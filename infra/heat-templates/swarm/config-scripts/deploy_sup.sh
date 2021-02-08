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

ret=0
# activation/desactivation sup sup_enable=true | false
if [ -z "$sup_enable" -o "$sup_enable" == "false" ] ; then
  echo "sup disable"
  notify_success "Start sup success ($ret)"
  exit 0
fi

env=$env
[ -z "${env}" ] && exit 1
export no_proxy=$no_proxy

sup_name=$sup_name
[ -z "${sup_name}" ] && exit 1

sup_version=$sup_version
[ -z "${sup_version}" ] && sup_version=latest

sup_archive_url=$sup_archive_repo
[ -z "$sup_archive_url" ] && exit 1

sup_archive=${sup_name}-${sup_version}-archive.tar.gz

echo "@sup ready to be deployed"

curl_args="--retry 1 --retry-delay 1 --retry-max-time 5 --fail"
cd /home/debian

message="config sup ${sup_archive} ${sup_version}"
echo "## $message"
cat <<EOF > /home/debian/deploy-sup.sh
#!/bin/bash
# deploy-sup
export no_proxy=$no_proxy
( echo "# download sup archive"
  [ -d "${sup_name}-dl" ] || mkdir ${sup_name}-dl
# TODO: X-Auth-Token
   cd ${sup_name}-dl
   curl $curl_args -k -L $sup_archive_url/${sup_version}/${sup_name}-VERSION -i || exit 1
   curl $curl_args -k -L $sup_archive_url/${sup_version}/$sup_archive -O || exit 1
)
( echo "# extract sup"
  [ -d "${sup_name}" ] || mkdir -p ${sup_name}
  cd ${sup_name} && tar -zxvf ../${sup_name}-dl/${sup_archive}
)
( echo "# download sup image"
  cd ${sup_name}
  make beat-get-build-image beat-load-image dml_url=$sup_archive_url publish_dir=""
)
( echo "# run sup"
  [ -f deploy.cfg ] && source deploy.cfg
  [ -f \${role}.cfg ] && source \${role}.cfg
  [ -f sup.cfg ] && source sup.cfg
   make -C ${sup_name} beat-down beat-up
)
EOF
chmod +x /home/debian/deploy-sup.sh

message="deploy sup ${sup_archive} ${sup_version}"
echo "## $message"
su - debian -c "bash -c /home/debian/deploy-sup.sh"
ret=$?

echo "# end postconf sup"
if [ "$ret" -gt 0 ] ;then
  notify_failure "Start sup failed ($ret)"
fi
if [ "$ret" -eq 0 ] ;then
  notify_success "Start sup success ($ret)"
fi
