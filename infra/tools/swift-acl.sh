#!/bin/bash
#
# configuration des ACL swift
#
set -e -o pipefail
# load lib
[ -f $(dirname $0)/deploy-lib.sh ] || exit 1
source $(dirname $0)/deploy-lib.sh

plateforme=$1
[ -z "$plateforme" ] && log_error 1 "ERROR: arg plateforme necessaire"

#
# configuration
## TODO: sortir la conf environnementale du script
#
## correspondance plateforme => zone
case $plateforme in
   debug|test|dev|qualif|prod|prod-int) echo "Running $plateforme" ;;
   *) echo "plateforme $plateforme inconnue"; exit 1 ;;
esac

default_conf="$(dirname $0)/../conf/default.cfg"
plateforme_conf="$(dirname $0)/../conf/${plateforme}.cfg"

if [ -f "${default_conf}" ] ; then
  echo "# Load config ${default_conf}"
  source ${default_conf}
fi

if [ -f "${plateforme_conf}" ] ; then
  echo "# Load config ${plateforme_conf}"
  source ${plateforme_conf}
fi



PARAM=heat-templates/swift/param/param-${plateforme}.sh

test -f $PARAM || { echo "$PARAM introuvable" ; exit 1 ; }
echo "# load $PARAM"
source $PARAM

eval $(swift auth)

DRY_RUN="${DRY_RUN:-echo }"

[ -z "$OS_STORAGE_URL" -o -z "$OS_AUTH_TOKEN" ] && { echo "OS_STORAGE_URL et OS_AUTH_TOKEN absent" ; exit 1 ; } 

${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat | grep "$PROJECT_ID$" || exit 1
#cat <<EOF
if [ -n "$IMAGES_CONTAINER" ] ;then
echo "# $IMAGES_CONTAINER:"
echo "#  acl read: $IMAGES_READ_ACL"
echo "#  acl write: $IMAGES_WRITE_ACL"
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $IMAGES_CONTAINER || true
[ -n "$IMAGES_READ_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -r "$IMAGES_READ_ACL" $IMAGES_CONTAINER
[ -n "$IMAGES_WRITE_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -w "$IMAGES_WRITE_ACL" $IMAGES_CONTAINER
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $IMAGES_CONTAINER
fi

if [ -n "$INFRA_CONTAINER" ] ;then
echo "# $INFRA_CONTAINER:"
echo "#  acl read: $INFRA_READ_ACL"
echo "#  acl write: $INFRA_WRITE_ACL"
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $INFRA_CONTAINER || true
[ -n "$INFRA_READ_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -r "$INFRA_READ_ACL" $INFRA_CONTAINER
[ -n "$INFRA_WRITE_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -w "$INFRA_WRITE_ACL" $INFRA_CONTAINER
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $INFRA_CONTAINER
fi

if [ -n "$COMMON_CONTAINER" ] ;then
echo "# $COMMON_CONTAINER:"
echo "#  acl read: $COMMON_READ_ACL"
echo "#  acl write: $COMMON_WRITE_ACL"
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $COMMON_CONTAINER || true
[ -n "$COMMON_READ_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -r "$COMMON_READ_ACL" $COMMON_CONTAINER
[ -n "$COMMON_WRITE_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -w "$COMMON_WRITE_ACL" $COMMON_CONTAINER
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $COMMON_CONTAINER
fi


if [ -n "$PLATEFORME_CONTAINER" ] ;then
echo "# $PLATEFORME_CONTAINER:"
echo "#  acl read: $PLATEFORME_READ_ACL"
echo "#  acl write: $PLATEFORME_WRITE_ACL"
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $PLATEFORME_CONTAINER || true
[ -n "$PLATEFORME_READ_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -r "$PLATEFORME_READ_ACL" $PLATEFORME_CONTAINER
[ -n "$PLATEFORME_WRITE_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -w "$PLATEFORME_WRITE_ACL" $PLATEFORME_CONTAINER
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $PLATEFORME_CONTAINER
fi

if [ -n "$PLATEFORME_DEV_CONTAINER" ] ;then
echo "# $PLATEFORME_DEV_CONTAINER:"
echo "#  acl read: $PLATEFORME_DEV_READ_ACL"
echo "#  acl write: $PLATEFORME_DEV_WRITE_ACL"
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $PLATEFORME_DEV_CONTAINER || true
[ -n "$PLATEFORME_DEV_READ_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -r "$PLATEFORME_DEV_READ_ACL" $PLATEFORME_DEV_CONTAINER
[ -n "$PLATEFORME_DEV_WRITE_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -w "$PLATEFORME_DEV_WRITE_ACL" $PLATEFORME_DEV_CONTAINER
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $PLATEFORME_DEV_CONTAINER
fi


if [ -n "$PLATEFORME_PROD_CONTAINER" ] ;then
echo "# $PLATEFORME_PROD_CONTAINER:"
echo "#  acl read: $PLATEFORME_PROD_READ_ACL"
echo "#  acl write: $PLATEFORME_PROD_WRITE_ACL"
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $PLATEFORME_PROD_CONTAINER || true
[ -n "$PLATEFORME_PROD_READ_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -r "$PLATEFORME_PROD_READ_ACL" $PLATEFORME_PROD_CONTAINER
[ -n "$PLATEFORME_PROD_WRITE_ACL" ] && ${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -w "$PLATEFORME_PROD_WRITE_ACL" $PLATEFORME_PROD_CONTAINER
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $PLATEFORME_PROD_CONTAINER
fi


if [ -n "$LOGS_CONTAINER" ] ;then
echo "# $LOGS_CONTAINER:"
echo "#  acl read: $LOGS_READ_ACL"
echo "#  acl write: $LOGS_WRITE_ACL"
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $LOGS_CONTAINER || true
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -r "$LOGS_READ_ACL" -w "$LOGS_WRITE_ACL" $LOGS_CONTAINER
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $LOGS_CONTAINER
fi

if [ -n "$DATA_CONTAINER" ] ;then
echo "# $DATA_CONTAINER:"
echo "#  acl read: $DATA_READ_ACL"
echo "#  acl write: $DATA_WRITE_ACL"
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $DATA_CONTAINER || true
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -r "$DATA_READ_ACL" -w "$DATA_WRITE_ACL" $DATA_CONTAINER
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $DATA_CONTAINER

echo "# ${DATA_CONTAINER}_segments:"
echo "#  acl read: $DATA_READ_ACL"
echo "#  acl write: $DATA_WRITE_ACL"
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat ${DATA_CONTAINER}_segments || true
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -r "$DATA_READ_ACL" -w "$DATA_WRITE_ACL" ${DATA_CONTAINER}_segments
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat ${DATA_CONTAINER}_segments
fi

if [ -n "$DATA_QUALIF_CONTAINER" ] ;then
echo "# $DATA_QUALIF_CONTAINER:"
echo "#  acl read: $DATA_QUALIF_READ_ACL"
echo "#  acl write: $DATA_QUALIF_WRITE_ACL"
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $DATA_QUALIF_CONTAINER || true
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN post -r "$DATA_QUALIF_READ_ACL" -w "$DATA_QUALIF_WRITE_ACL" $DATA_QUALIF_CONTAINER
${DRY_RUN} swift --os-storage-url $OS_STORAGE_URL --os-auth-token $OS_AUTH_TOKEN stat $DATA_QUALIF_CONTAINER
fi


#EOF
