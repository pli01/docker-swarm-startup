#!/bin/bash
#
# script de deploiement: blue/green
#
set -e -o pipefail

# load lib
[ -f $(dirname $0)/deploy-lib.sh ] || exit 1
source $(dirname $0)/deploy-lib.sh

plateforme=$1
[ -z "$plateforme" ] && log_error 1 "ERROR: arg plateforme necessaire"


openstack_args="${openstack_args:-} --insecure "
STACK_DIR="heat-templates"
DRY_RUN="${DRY_RUN:-echo }"
CREATE_IF_NOT_EXIST="${CREATE_IF_NOT_EXIST:-false}"
STACK_HTTP_PROXY_DELETE="${STACK_HTTP_PROXY_DELETE:-}"
STACK_INFRA_DELETE="${STACK_INFRA_DELETE:-}"
export PYTHONUNBUFFERED=true

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

#
# Check root volume
#
stack=root-volume-latest
eval $(get_param_stack_color ${stack})
echo "# Check root volume stack: $stack $stack_root_volume"
if ! stack_is_present $stack_root_volume; then
  if create_if_not_exist ;then
     echo "# Create root-volume-latest stack: $stack $stack_root_volume"
     stack_validate $stack_root_volume $STACK_DIR/$stack_root_volume_template $STACK_DIR/$stack_root_volume_param $plateforme $zone
     stack_create $stack_root_volume $STACK_DIR/$stack_root_volume_template $STACK_DIR/$stack_root_volume_param $plateforme $zone
   else
     log_error "1" "ERROR: $stack_root_volume introuvable"
     exit 1
   fi
else
  if [ ! -z "$STACK_ROOT_VOLUME_DELETE" ] ; then
     echo "# Recreate root-volume-latest stack: $stack $stack_root_volume"
     stack_check $stack_root_volume
     stack_delete $stack_root_volume
     stack_validate $stack_root_volume $STACK_DIR/$stack_root_volume_template $STACK_DIR/$stack_root_volume_param $plateforme $zone
     stack_create $stack_root_volume $STACK_DIR/$stack_root_volume_template $STACK_DIR/$stack_root_volume_param $plateforme $zone
  else
    echo "# Don't touch root-volume-latest stack"
  fi
fi
# get root_volume id
eval $(get_stack_output_value ${stack_root_volume} os_vol_id)
root_volume_id=$os_vol_id
echo "${stack} root_volume_id: $os_vol_id"

#
# Check fip
#
for stack in bastion leader ; do
  eval $(get_param_stack_color ${stack})
  echo "# Check floating-ip stack: $stack $stack_fip"
  if ! stack_is_present $stack_fip; then
   if create_if_not_exist ;then
     echo "# Create floating-ip stack: $stack $stack_fip"
     stack_validate $stack_fip $STACK_DIR/$stack_fip_template $STACK_DIR/$stack_fip_param $plateforme $zone
     stack_create $stack_fip $STACK_DIR/$stack_fip_template $STACK_DIR/$stack_fip_param $plateforme $zone
   else
     log_error "1" "ERROR: $stack_fip introuvable"
     exit 1
   fi
  fi
  # get front fip id
  eval $(get_stack_output_value ${stack_fip} floating_ip_id)
  echo "${stack} floating_ip_id: $floating_ip_id"
  eval $(get_stack_output_value ${stack_fip} floating_ip_address)
  echo "${stack} floating_ip_address: $floating_ip_address"
done

#
# network (router,network, subnet)
#
# get param
stack=network
eval $(get_param_stack_color ${stack})
echo "# Check network stack: $stack $stack_infra"
if ! stack_is_present $stack_infra; then
 if create_if_not_exist ; then
   echo "# Create network stack: $stack $stack_infra"
   stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone
   stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone
 else
   log_error 1 "ERROR: Stack NET ${stack_infra} absente"
   exit 1
 fi
fi
# get infra id
echo "# Get ${stack_infra} output value"
eval $(get_stack_output_value ${stack_infra} router_id)
echo "  router_id: $router_id"
eval $(get_stack_output_value ${stack_infra} net_id)
echo "  net_id: $net_id"
eval $(get_stack_output_value ${stack_infra} subnet_id)
echo "  subnet_id: $subnet_id"

eval $(get_stack_parameter_value ${stack_infra} subnet_cidr)
echo "  subnet_cidr: $subnet_cidr"

#
# keypair
#
stack=keypair
eval $(get_param_stack_color ${stack})
echo "# Check keypair stack: $stack $stack_keypair"

if ! stack_is_present $stack_keypair; then
 if create_if_not_exist ; then
   echo "# Create keypair stack: $stack $stack_keypair"
   stack_validate $stack_keypair $STACK_DIR/$stack_keypair_template $STACK_DIR/$stack_keypair_param $plateforme $zone \
 "$parameters"

   stack_create $stack_keypair $STACK_DIR/$stack_keypair_template $STACK_DIR/$stack_keypair_param $plateforme $zone \
 "$parameters"

 else
   log_error 1 "ERROR: Stack keypair ${stack_keypair} absente"
   exit 1
 fi
fi
# get keypair
echo "# Get ${stack_keypair} output value"
eval $(get_stack_output_value_base64 ${stack_keypair} public_key)
keypair_public_key=$public_key
echo "keypair_public_key: $keypair_public_key"

eval $(get_stack_output_value_base64 ${stack_keypair} private_key)
keypair_private_key=$private_key
echo "keypair_private_key: $keypair_private_key"
#
# bastion
#
stack=bastion
eval $(get_param_stack_color ${stack})
eval $(get_stack_output_value ${stack_fip} floating_ip_id)
bastion_floating_ip_id=$floating_ip_id

echo "# Check bastion stack: $stack $stack_infra"
if [ -z "$net_id" -o -z "$subnet_id" -o -z "$bastion_floating_ip_id" -o -z "$root_volume_id" ] ; then
   log_error 1 "ERROR: parameters stack bastion ${stack_infra} absents"
   exit 1
fi
parameters="front_network=$net_id;front_subnet=$subnet_id;floatingip_id_bastion=$bastion_floating_ip_id;source_volid=$root_volume_id;deploy_ssh_public_key=$keypair_public_key;deploy_ssh_private_key=$keypair_private_key"

if ! stack_is_present $stack_infra; then
 if create_if_not_exist ; then
   echo "# Create bastion stack: $stack $stack_infra"
   stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

   stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

 else
   log_error 1 "ERROR: Stack bastion ${stack_infra} absente"
   exit 1
 fi
fi
# get bastion id
echo "# Get ${stack_infra} output value"
eval $(get_stack_output_value ${stack_infra} bastion_id)
echo "  bastion_id: $bastion_id"
eval $(get_stack_output_value ${stack_infra} bastion_public_ip_address)
echo "  bastion_public_ip_address: $bastion_public_ip_address"
eval $(get_stack_output_value ${stack_infra} bastion_private_ip_address)
echo "  bastion_private_ip_address: $bastion_private_ip_address"

#
# deploy http-proxy
#
stack=http-proxy
eval $(get_param_stack_color ${stack})

if [ -z "$net_id" -o -z "$subnet_id" -o -z "$bastion_private_ip_address"  -o -z "$root_volume_id" ] ; then
   log_error 1 "ERROR: parameters stack http-proxy ${stack_infra} absents"
   exit 1
fi
parameters="front_network=$net_id;front_subnet=$subnet_id;ssh_access_cidr=${bastion_private_ip_address}/32;source_volid=$root_volume_id;deploy_ssh_public_key=$keypair_public_key"

if ! stack_is_present $stack_infra ; then
  echo "# Create $stack_infra"
  stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

  stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
else
  if [ ! -z "$STACK_HTTP_PROXY_DELETE" ] ; then
    echo "# Recreate $stack_infra"
    stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

    stack_delete $stack_infra
    stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
  else
    echo "# Don't touch $stack_infra"
  fi
fi

echo "# Get ${stack_infra} http_proxy_private_ip_address "
eval $(get_stack_output_value ${stack_infra} http_proxy_private_ip_address)
echo "http_proxy_private_ip_address: $http_proxy_private_ip_address"
echo "# Get ${stack_infra} http_proxy_public_ip_address "
eval $(get_stack_output_value ${stack_infra} http_proxy_public_ip_address)
echo "http_proxy_public_ip_address: $http_proxy_public_ip_address"

#
# deploy security-group
#
stack=security-group
eval $(get_param_stack_color ${stack})

if [ -z "$bastion_private_ip_address" -o -z "$subnet_cidr" ] ; then
   log_error 1 "ERROR: parameters stack security-group ${stack_infra} absents"
   exit 1
fi
#parameters="ssh_access_cidr=${bastion_private_ip_address}/32"
parameters="ssh_access_cidr=${subnet_cidr}"

if ! stack_is_present $stack_infra ; then
  echo "# Create $stack_infra"
  stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

  stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
else
  if [ ! -z "$STACK_SG_UPDATE" ] ; then
    echo "# Recreate $stack_infra"
    stack_check $stack_infra
    stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

    stack_update $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
  else
    echo "# Don't touch $stack_infra"
  fi
fi

echo "# Get ${stack_infra} node_securitygroup_id "
eval $(get_stack_output_value ${stack_infra} node_securitygroup_id)

if [ -n "$DEPLOY_LEADER" ] ; then
#
# leader
#
stack=leader
eval $(get_param_stack_color ${stack})
eval $(get_stack_output_value ${stack_fip} floating_ip_id)
leader_floating_ip_id=$floating_ip_id


##
## Check leader volume
##
echo "# Check leader volume stack: $stack $stack_volume"
if ! stack_is_present $stack_volume; then
   if create_if_not_exist ;then
     echo "# Create $stack volume stack"
     stack_validate $stack_volume $STACK_DIR/$stack_volume_template $STACK_DIR/$stack_volume_param $plateforme $zone
     stack_create $stack_volume $STACK_DIR/$stack_volume_template $STACK_DIR/$stack_volume_param $plateforme $zone
   else
     log_error 1 "ERROR: Stack VOLUME ${stack_volume} absente"
     exit 1
   fi
fi
# get volume id
echo "# Get ${stack_volume} data_volume_id "
eval $(get_stack_output_value ${stack_volume} data_volume_id)
echo "data_volume_id: $data_volume_id"

if [ -z "$net_id" -o -z "$subnet_id" -o -z "$bastion_private_ip_address" -o -z "$root_volume_id" -o -z "$leader_floating_ip_id" -o -z "$node_securitygroup_id" -o -z "$data_volume_id" ] ; then
   log_error 1 "ERROR: parameters stack leader ${stack_infra} absents"
   exit 1
fi
parameters="front_network=$net_id;front_subnet=$subnet_id;ssh_access_cidr=${bastion_private_ip_address}/32;source_volid=$root_volume_id;floating_ip_id=$leader_floating_ip_id;node_securitygroup=$node_securitygroup_id;data_volume_id=$data_volume_id;deploy_ssh_public_key=$keypair_public_key"

if ! stack_is_present $stack_infra ; then
  echo "# Create $stack_infra"
  stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

  stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
else
  if [ ! -z "$STACK_LEADER_DELETE" ] ; then
    echo "# Recreate $stack_infra"
    stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

    stack_delete $stack_infra
    stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
  else
    echo "# Don't touch $stack_infra"
  fi
fi

echo "# Get ${stack_infra} leader_private_ip_address "
eval $(get_stack_output_value ${stack_infra} leader_private_ip_address)
eval $(get_swarm_leader_output_value ${stack_infra} leader_private_ip_address )
echo "leader_private_ip_address: $leader_private_ip_address"
echo "swarm_leader: $swarm_leader"
eval $(get_swarm_token_output_value ${stack_infra} swarm_token worker)
swarm_token_worker=$worker
echo "swarm_token_worker: $swarm_token_worker"
eval $(get_swarm_token_output_value ${stack_infra} swarm_token manager)
swarm_token_manager=$manager
echo "swarm_token_manager: $swarm_token_manager"
#echo "# Get ${stack_infra} leader_public_ip_address "
#eval $(get_stack_output_value ${stack_infra} leader_public_ip_address)
#echo "leader_public_ip_address: $leader_public_ip_address"

fi

if [ -n "$DEPLOY_MANAGER" ] ; then
#
# manager
#
AVAILABILITY_ZONE_LIST="AZ1 AZ2 AZ3"
#AVAILABILITY_ZONE_LIST="AZ1"
for availability_zone in $AVAILABILITY_ZONE_LIST ; do
echo "# Provision manager in $availability_zone"
stack=manager-$availability_zone
eval $(get_param_stack_color ${stack})
#eval $(get_stack_output_value ${stack_fip} floating_ip_id)

##
## Check manager volume
##
#echo "# Check manager volume stack: $stack $stack_volume"
#if ! stack_is_present $stack_volume; then
#   if create_if_not_exist ;then
#     echo "# Create $stack volume stack"
#     stack_validate $stack_volume $STACK_DIR/$stack_volume_template $STACK_DIR/$stack_volume_param $plateforme $zone
#     stack_create $stack_volume $STACK_DIR/$stack_volume_template $STACK_DIR/$stack_volume_param $plateforme $zone
#   else
#     log_error 1 "ERROR: Stack VOLUME ${stack_volume} absente"
#     exit 1
#   fi
#fi
## get volume id
#echo "# Get ${stack_volume} data_volume_id "
#eval $(get_stack_output_value ${stack_volume} data_volume_id)
#echo "data_volume_id: $data_volume_id"
#

if [ -z "$net_id" -o -z "$subnet_id" -o -z "$bastion_private_ip_address" -o -z "$root_volume_id" -o -z "$node_securitygroup_id" \
   -o -z "$swarm_token_manager" -o -z "$swarm_leader" ] ; then
   log_error 1 "ERROR: parameters stack manager ${stack_infra} absents"
   exit 1
fi
parameters="front_network=$net_id;front_subnet=$subnet_id;ssh_access_cidr=${bastion_private_ip_address}/32;source_volid=$root_volume_id;node_securitygroup=$node_securitygroup_id;swarm_token=$swarm_token_manager;swarm_leader=$swarm_leader;deploy_ssh_public_key=$keypair_public_key"

if ! stack_is_present $stack_infra ; then
  echo "# Create $stack_infra"
  stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

  stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
else
  if [ ! -z "$STACK_INFRA_DELETE" ] ; then
    echo "# Recreate $stack_infra"
    stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

    stack_delete $stack_infra
    stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
  else
    echo "# Don't touch $stack_infra"
  fi
fi

echo "# Get ${stack_infra} manager_private_ip_address "
eval $(get_stack_output_value ${stack_infra} manager_private_ip_address)
echo "manager_private_ip_address: $manager_private_ip_address"
echo "# Get ${stack_infra} manager_public_ip_address "
eval $(get_stack_output_value ${stack_infra} manager_public_ip_address)
echo "manager_public_ip_address: $manager_public_ip_address"

done
fi


if [ -n "$DEPLOY_WORKER" ] ; then
#
# worker
#
AVAILABILITY_ZONE_LIST="AZ1 AZ2 AZ3"
#AVAILABILITY_ZONE_LIST="AZ1"
for availability_zone in $AVAILABILITY_ZONE_LIST ; do
echo "# Provision worker in $availability_zone"
stack=worker-$availability_zone
eval $(get_param_stack_color ${stack})
#eval $(get_stack_output_value ${stack_fip} floating_ip_id)

##
## Check worker volume
##
#echo "# Check worker volume stack: $stack $stack_volume"
#if ! stack_is_present $stack_volume; then
#   if create_if_not_exist ;then
#     echo "# Create $stack volume stack"
#     stack_validate $stack_volume $STACK_DIR/$stack_volume_template $STACK_DIR/$stack_volume_param $plateforme $zone
#     stack_create $stack_volume $STACK_DIR/$stack_volume_template $STACK_DIR/$stack_volume_param $plateforme $zone
#   else
#     log_error 1 "ERROR: Stack VOLUME ${stack_volume} absente"
#     exit 1
#   fi
#fi
## get volume id
#echo "# Get ${stack_volume} data_volume_id "
#eval $(get_stack_output_value ${stack_volume} data_volume_id)
#echo "data_volume_id: $data_volume_id"
#

if [ -z "$net_id" -o -z "$subnet_id" -o -z "$bastion_private_ip_address" -o -z "$root_volume_id" -o -z "$node_securitygroup_id" \
   -o -z "$swarm_token_worker" -o -z "$swarm_leader" ] ; then
   log_error 1 "ERROR: parameters stack worker ${stack_infra} absents"
   exit 1
fi
parameters="front_network=$net_id;front_subnet=$subnet_id;ssh_access_cidr=${bastion_private_ip_address}/32;source_volid=$root_volume_id;node_securitygroup=$node_securitygroup_id;swarm_token=$swarm_token_worker;swarm_leader=$swarm_leader;deploy_ssh_public_key=$keypair_public_key"

if ! stack_is_present $stack_infra ; then
  echo "# Create $stack_infra"
  stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

  stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
else
  if [ ! -z "$STACK_INFRA_DELETE" ] ; then
    echo "# Recreate $stack_infra"
    stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

    stack_delete $stack_infra
    stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
  else
    echo "# Don't touch $stack_infra"
  fi
fi

echo "# Get ${stack_infra} worker_private_ip_address "
eval $(get_stack_output_value ${stack_infra} worker_private_ip_address)
echo "worker_private_ip_address: $worker_private_ip_address"
#echo "# Get ${stack_infra} worker_public_ip_address "
#eval $(get_stack_output_value ${stack_infra} worker_public_ip_address)
#echo "worker_public_ip_address: $worker_public_ip_address"

done

fi


if [ -n "$DEPLOY_STACK_DEPLOYER" ] ; then
#
# stack-deployer
#
#AVAILABILITY_ZONE_LIST="AZ1 AZ2 AZ3"
AVAILABILITY_ZONE_LIST="AZ1"
for availability_zone in $AVAILABILITY_ZONE_LIST ; do
echo "# Provision stack-deployer in $availability_zone"
stack=stack-deployer-$availability_zone
eval $(get_param_stack_color ${stack})
#eval $(get_stack_output_value ${stack_fip} floating_ip_id)

##
## Check stack-deployer volume
##
#echo "# Check stack-deployer volume stack: $stack $stack_volume"
#if ! stack_is_present $stack_volume; then
#   if create_if_not_exist ;then
#     echo "# Create $stack volume stack"
#     stack_validate $stack_volume $STACK_DIR/$stack_volume_template $STACK_DIR/$stack_volume_param $plateforme $zone
#     stack_create $stack_volume $STACK_DIR/$stack_volume_template $STACK_DIR/$stack_volume_param $plateforme $zone
#   else
#     log_error 1 "ERROR: Stack VOLUME ${stack_volume} absente"
#     exit 1
#   fi
#fi
## get volume id
#echo "# Get ${stack_volume} data_volume_id "
#eval $(get_stack_output_value ${stack_volume} data_volume_id)
#echo "data_volume_id: $data_volume_id"
#

if [ -z "$net_id" -o -z "$subnet_id" -o -z "$bastion_private_ip_address" -o -z "$root_volume_id" -o -z "$node_securitygroup_id" \
   -o -z "$swarm_leader" ] ; then
   log_error 1 "ERROR: parameters stack stack-deployer ${stack_infra} absents"
   exit 1
fi
parameters="front_network=$net_id;front_subnet=$subnet_id;ssh_access_cidr=${bastion_private_ip_address}/32;source_volid=$root_volume_id;node_securitygroup=$node_securitygroup_id;swarm_leader=$swarm_leader;deploy_ssh_public_key=$keypair_public_key"

if ! stack_is_present $stack_infra ; then
  echo "# Create $stack_infra"
  stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

  stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
else
  if [ ! -z "$STACK_INFRA_DELETE" ] ; then
    echo "# Recreate $stack_infra"
    stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

    stack_delete $stack_infra
    stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
  else
    echo "# Don't touch $stack_infra"
  fi
fi

echo "# Get ${stack_infra} stack-deployer_private_ip_address "
eval $(get_stack_output_value ${stack_infra} stack_deployer_private_ip_address)
echo "stack-deployer_private_ip_address: ${stack_deployer_private_ip_address}"
echo "# Get ${stack_infra} stack_deployer_public_ip_address "
eval $(get_stack_output_value ${stack_infra} stack_deployer_public_ip_address)
echo "stack-deployer_public_ip_address: $stack_deployer_public_ip_address"

done
fi



exit 0
###################### END
#
# LB stack
#
stack=lb
eval $(get_param_stack_color ${stack})
if [ -z "$net_id" -o -z "$subnet_id" -o -z "$bastion_private_ip_address" ] ; then
   log_error 1 "ERROR: parameters stack bastion ${stack_infra} absents"
   exit 1
fi
parameters="front_network=$net_id;front_subnet=$subnet_id;ssh_access_cidr=${bastion_private_ip_address}/32"


if [ -z "$candidat_floating_ip_id" -o \
     -z "$candidat_front_private_ip_address" -o \
     -z "$candidat_front_private_port" -o \
     -z "$admin_floating_ip_id" -o \
     -z "$admin_front_private_ip_address" -o \
     -z "$admin_front_private_port" ] ; then
   log_error 1 "ERROR: parameters stack ${STACK_LB_NAME} absents"
   exit 1
fi
parameters="$parameters;floatingip_id_candidat=$candidat_floating_ip_id;servers_candidat=$candidat_front_private_ip_address;app_port_candidat=$candidat_front_private_port"
parameters="$parameters;floatingip_id_admin=$admin_floating_ip_id;servers_admin=$admin_front_private_ip_address;app_port_admin=$admin_front_private_port"
parameters="$parameters;color=$next_stack_color"

# update lb with $next_stack_color
if ! stack_is_present ${stack_infra} ; then
  echo "# Create LB $next_stack_color"
  stack_create_lb $next_stack_color \
   $parameters
else
  echo "# Update LB $next_stack_color"
  stack_update_lb $next_stack_color \
   $parameters
fi

# test new running color stack (timeout 30s)
#
# TODO:
# if ! do_test_on_new_lb ;then
#   echo "# Test on $next_stack_color failed, revert on last color"
#   eval $(get_param_stack_color ${next_stack_color})
#   stack_update_lb $next_stack_color
# else
#   echo "# Test on $next_stack_color success"
# fi

#
get_lb_last_state ${stack_infra}
echo "# LB is $next_stack_color"
echo "# admin lb public ip_address: $admin_floating_ip_address"
echo "# candidat lb public ip_address: $candidat_floating_ip_address"
echo "# bastion ssh ip address: $bastion_floating_ip_address"
