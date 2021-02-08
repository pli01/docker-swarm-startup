#
# common blue-green lib
#
function create_if_not_exist() {
  eval $CREATE_IF_NOT_EXIST ; return $?
}

function log_error(){
 echo "$@"
 exit $1
}

function stack_is_present(){
  [ -z "$1" ] && log_error 1 "argument stack absent"
  local stack_name=$1
  local stack_status=""
  local ret=0;
  eval $(openstack $openstack_args stack show -c "stack_status" -f shell $stack_name ) ; ret=$?
  [ "$ret" -gt 0 ] && return $ret
  case "$stack_status" in
    *COMPLETE|*FAILED) ret=0 ;;
    *) ret=2 ;;
  esac
  [ -z "$stack_status" ] && ret=1
  echo "stack_status=$stack_status"
  return $ret
}

function get_stack_output_value(){
  [ -z "$1" -o -z "$2" ] && log_error 1 "aucun argument"
  local stack_name=$1
  local output_var=$2
  ret=0
  local output_value="" ; eval $(openstack $openstack_args stack output show -c "output_value" -f shell $stack_name "$output_var" ) ; [ -z "$output_value" ] && ret=1 || echo "$output_var=\"$output_value\" ; "
  return $ret
}

function get_stack_output_value_base64(){
  [ -z "$1" -o -z "$2" ] && log_error 1 "aucun argument"
  local stack_name=$1
  local output_var=$2
  ret=0
  local output_value="" ; output_value=$(openstack $openstack_args stack output show -c "output_value" -f value $stack_name "$output_var" | base64 -w0 - )
  [ -z "$output_value" ] && ret=1 || echo "$output_var=\"$output_value\" ; "
  return $ret
}

function get_swarm_token_output_value(){
  [ -z "$1" -o -z "$2" -o -z "$3" ] && log_error 1 "aucun argument"
  local stack_name=$1
  local output_var=$2
  local parameter=$3
  ret=0
  local output_value="" ; output_value=$(openstack $openstack_args stack output show -c "output_value" -f json $stack_name "$output_var" | jq -re '.[][0]' |jq -re ".$parameter" )
  ret=$?
  [ -z "$output_value" ] && ret=1 || echo "$parameter=$output_value ; "
  return $ret
}

function get_swarm_leader_output_value(){
  [ -z "$1" -o -z "$2" ] && log_error 1 "aucun argument"
  local stack_name=$1
  local output_var=$2
  ret=0
  local output_value="" ; output_value=$(openstack $openstack_args stack output show -c "output_value" -f json $stack_name "$output_var" | jq -re '.[][0]' )
  ret=$?
  [ -z "$output_value" ] && ret=1 || echo "swarm_leader=$output_value ; "
  return $ret
}


function get_stack_parameter_value(){
  [ -z "$1" -o -z "$2" ] && log_error 1 "aucun argument"
  local stack_name=$1
  local parameter=$2
  ret=0
  local parameters="" ;
  eval $(openstack $openstack_args stack show -f shell -c parameters $stack_name || echo "false")
  ret=$?
  output_value=$(echo "$parameters" | jq -r ".$parameter")
  ret=$?
  [ -z "$output_value" ] && ret=1 || echo "$parameter=$output_value ; "
  return $ret
}

function get_stack_validate_parameter_value(){
  local stack_name=$1
  local stack_template=$2
  local stack_param=$3
  local plateforme=$4
  local zone=$5
  local parameter=$6
  local input_parameter=$7
  local parameter_opt
  [ -z "$stack_name" -o \
    -z "$stack_template" -o \
    -z "$stack_param" -o \
    -z "$plateforme" -o \
    -z "$zone" ] && log_error 1 "stack_validate: argument manquant"
  [ ! -z "$parameter" ] && parameter_opt="--parameter \"$parameter\""
  local output_value=""
  local jsonoutput_value=$(  openstack $openstack_args orchestration template validate -t $stack_template -e $stack_param -f json $parameter_opt || echo '{}' )
  ret=$?
  output_value=$( echo "$jsonoutput_value" | jq --arg input_parameter $input_parameter -r -e "if .Parameters.$input_parameter.Value then .Parameters.$input_parameter.Value  else if  .Parameters.$input_parameter.Default then  .Parameters.$input_parameter.Default else empty end end")
  ret=$?
  [ -z "$output_value" ] && ret=1 || echo "$input_parameter=$output_value ;"
  return $?
}



function get_fip_id(){
  [ -z "$1" ] && log_error 1 "aucun argument"
  local stack_name=$1
  ret=0
  local output_value="" ; eval $(openstack $openstack_args stack output show -c "output_value" -f shell $stack_name front_floating_ip_id ) ; [ -z "$output_value" ] && ret=1 || echo "front_floating_ip_id=$output_value ; "
  local output_value="" ; eval $(openstack $openstack_args stack output show -c "output_value" -f shell $stack_name bastion_floating_ip_id ) ; [ -z "$output_value" ] && ret=1 || echo "bastion_floating_ip_id=$output_value ;"
  return $ret
}

function get_fip_ip_address(){
  [ -z "$1" ] && log_error 1 "aucun argument"
  local stack_name=$1
  ret=0
  local output_value="" ; eval $(openstack $openstack_args stack output show -c "output_value" -f shell $stack_name front_floating_ip_address ) ; [ -z "$output_value" ] && ret=1 || echo "front_floating_ip_address=$output_value ; "
  local output_value="" ; eval $(openstack $openstack_args stack output show -c "output_value" -f shell $stack_name bastion_floating_ip_address ) ; [ -z "$output_value" ] && ret=1 || echo "bastion_floating_ip_address=$output_value ;"
  return $ret
}


function get_volume_id(){
  [ -z "$1" ] && log_error 1 "aucun argument"
  local stack_name=$1
  ret=0
  output_value="" ; eval $(openstack $openstack_args stack output show -c "output_value" -f shell $stack_name data_volume_id ) ; [ -z "$output_value" ] && ret=1 || echo "data_volume_id=$output_value ; "
  return $ret
}


function stack_delete(){
  echo "# stack_delete $@"
  $DRY_RUN stack_check $1
  $DRY_RUN openstack $openstack_args stack delete --yes --wait $1
  return $?
}

function stack_validate(){
  echo "# stack_validate $@"
   # stack_create ${STACK_INFRA_NAME} ${STACK_DIR}/${STACK_INFRA_TEMPLATE} ${STACK_DIR}/${STACK_INFRA_PARAM} $plateforme $zone
  local stack_name=$1
  local stack_template=$2
  local stack_param=$3
  local plateforme=$4
  local zone=$5
  local parameter=$6
  local parameter_opt
  [ -z "$stack_name" -o \
    -z "$stack_template" -o \
    -z "$stack_param" -o \
    -z "$plateforme" -o \
    -z "$zone" ] && log_error 1 "stack_validate: argument manquant"
  [ ! -z "$parameter" ] && parameter_opt="--parameter \"$parameter\""
  $DRY_RUN openstack $openstack_args orchestration template validate -t $stack_template -e $stack_param -f json $parameter_opt
  return $?
}


function stack_create(){
  echo "# stack_create $@"
   # stack_create ${STACK_INFRA_NAME} ${STACK_DIR}/${STACK_INFRA_TEMPLATE} ${STACK_DIR}/${STACK_INFRA_PARAM} $plateforme $zone
   local stack_name=$1
   local stack_template=$2
   local stack_param=$3
   local plateforme=$4
   local zone=$5
   local parameter=$6
   local parameter_opt
  [ -z "$stack_name" -o \
    -z "$stack_template" -o \
    -z "$stack_param" -o \
    -z "$plateforme" -o \
    -z "$zone" ] && log_error 1 "stack_create: argument manquant"
  [ ! -z "$parameter" ] && parameter_opt="--parameter \"$parameter\""
  echo "# stack_create (dry run) $@"
  $DRY_RUN openstack $openstack_args stack create --dry-run --wait -t $stack_template -e $stack_param -f json $parameter_opt $stack_name
  [ "$?" -gt 0 ] && return $?
  echo "# stack_create (do it for real) $@"
  $DRY_RUN openstack $openstack_args stack create --wait -t $stack_template -e $stack_param $parameter_opt $stack_name
  return $?
}

function stack_update(){
  echo "# stack_update $@"
   local stack_name=$1
   local stack_template=$2
   local stack_param=$3
   local plateforme=$4
   local zone=$5
   local parameter=$6
   local parameter_opt
  [ -z "$stack_name" -o \
    -z "$stack_template" -o \
    -z "$stack_param" -o \
    -z "$plateforme" -o \
    -z "$zone" ] && log_error 1 "stack_update: argument manquant"
  [ ! -z "$parameter" ] && parameter_opt="--parameter \"$parameter\""

  $DRY_RUN openstack $openstack_args stack update --wait -t $stack_template -e $stack_param $parameter_opt $stack_name
  return $?
}

function stack_check(){
  echo "# stack_check $@"
  local stack_name=$1
  [ -z "$stack_name" ] && log_error 1 "stack_check: argument manquant"
  $DRY_RUN openstack $openstack_args stack check --wait $stack_name
  return $?
}

function get_param_stack_color(){
  ret=1
  case $1 in
   root-volume-latest) ret=0;
     echo "stack_root_volume=$STACK_ROOT_VOLUME_NAME;"
     echo "stack_root_volume_template=$STACK_ROOT_VOLUME_TEMPLATE;"
     echo "stack_root_volume_param=$STACK_ROOT_VOLUME_PARAM;"
   ;;
   network) ret=0
     echo "stack_infra=$STACK_NETWORK_NAME;"
     echo "stack_infra_template=$STACK_NETWORK_TEMPLATE;"
     echo "stack_infra_param=$STACK_NETWORK_PARAM;"
   ;;
   security-group) ret=0
     echo "stack_infra=$STACK_SG_NAME;"
     echo "stack_infra_template=$STACK_SG_TEMPLATE;"
     echo "stack_infra_param=$STACK_SG_PARAM;"
   ;;
   keypair) ret=0
     echo "stack_keypair=$STACK_KEYPAIR_NAME;"
     echo "stack_keypair_template=$STACK_KEYPAIR_TEMPLATE;"
     echo "stack_keypair_param=$STACK_KEYPAIR_PARAM;"
   ;;
   bastion) ret=0
     echo "stack_fip=$STACK_FIP_BASTION_NAME;"
     echo "stack_fip_template=$STACK_FIP_BASTION_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_BASTION_PARAM;"
     echo "stack_infra=$STACK_BASTION_NAME;"
     echo "stack_infra_template=$STACK_BASTION_TEMPLATE;"
     echo "stack_infra_param=$STACK_BASTION_PARAM;"
   ;;
   http-proxy) ret=0;
     echo "stack_infra=$STACK_HTTP_PROXY_NAME;"
     echo "stack_infra_template=$STACK_HTTP_PROXY_TEMPLATE;"
     echo "stack_infra_param=$STACK_HTTP_PROXY_PARAM;"
   ;;
   leader) ret=0;
     echo "stack_fip=$STACK_FIP_LEADER_NAME;"
     echo "stack_fip_template=$STACK_FIP_LEADER_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_LEADER_PARAM;"
     echo "stack_volume=$STACK_LEADER_VOLUME_NAME;"
     echo "stack_volume_template=$STACK_LEADER_VOLUME_TEMPLATE;"
     echo "stack_volume_param=$STACK_LEADER_VOLUME_PARAM;"
     echo "stack_infra=$STACK_LEADER_NAME;"
     echo "stack_infra_template=$STACK_LEADER_TEMPLATE;"
     echo "stack_infra_param=$STACK_LEADER_PARAM;"
   ;;
   manager) ret=0;
     echo "stack_fip=$STACK_FIP_MANAGER_NAME;"
     echo "stack_fip_template=$STACK_FIP_MANAGER_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_MANAGER_PARAM;"
     echo "stack_volume=$STACK_MANAGER_VOLUME_NAME;"
     echo "stack_volume_template=$STACK_MANAGER_VOLUME_TEMPLATE;"
     echo "stack_volume_param=$STACK_MANAGER_VOLUME_PARAM;"
     echo "stack_infra=$STACK_MANAGER_NAME;"
     echo "stack_infra_template=$STACK_MANAGER_TEMPLATE;"
     echo "stack_infra_param=$STACK_MANAGER_PARAM;"
   ;;
   manager-AZ1) ret=0;
     echo "stack_fip=$STACK_FIP_MANAGER_AZ1_NAME;"
     echo "stack_fip_template=$STACK_FIP_MANAGER_AZ1_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_MANAGER_AZ1_PARAM;"
     echo "stack_volume=$STACK_MANAGER_VOLUME_NAME;"
     echo "stack_volume_template=$STACK_MANAGER_VOLUME_TEMPLATE;"
     echo "stack_volume_param=$STACK_MANAGER_VOLUME_PARAM;"
     echo "stack_infra=$STACK_MANAGER_AZ1_NAME;"
     echo "stack_infra_template=$STACK_MANAGER_AZ1_TEMPLATE;"
     echo "stack_infra_param=$STACK_MANAGER_AZ1_PARAM;"
   ;;
   manager-AZ2) ret=0;
     echo "stack_fip=$STACK_FIP_MANAGER_AZ2_NAME;"
     echo "stack_fip_template=$STACK_FIP_MANAGER_AZ2_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_MANAGER_AZ2_PARAM;"
     echo "stack_volume=$STACK_MANAGER_VOLUME_NAME;"
     echo "stack_volume_template=$STACK_MANAGER_VOLUME_TEMPLATE;"
     echo "stack_volume_param=$STACK_MANAGER_VOLUME_PARAM;"
     echo "stack_infra=$STACK_MANAGER_AZ2_NAME;"
     echo "stack_infra_template=$STACK_MANAGER_AZ2_TEMPLATE;"
     echo "stack_infra_param=$STACK_MANAGER_AZ2_PARAM;"
   ;;
   manager-AZ3) ret=0;
     echo "stack_fip=$STACK_FIP_MANAGER_AZ3_NAME;"
     echo "stack_fip_template=$STACK_FIP_MANAGER_AZ3_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_MANAGER_AZ3_PARAM;"
     echo "stack_volume=$STACK_MANAGER_VOLUME_NAME;"
     echo "stack_volume_template=$STACK_MANAGER_VOLUME_TEMPLATE;"
     echo "stack_volume_param=$STACK_MANAGER_VOLUME_PARAM;"
     echo "stack_infra=$STACK_MANAGER_AZ3_NAME;"
     echo "stack_infra_template=$STACK_MANAGER_AZ3_TEMPLATE;"
     echo "stack_infra_param=$STACK_MANAGER_AZ3_PARAM;"
   ;;
   worker) ret=0;
     echo "stack_fip=$STACK_FIP_WORKER_NAME;"
     echo "stack_fip_template=$STACK_FIP_WORKER_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_WORKER_PARAM;"
     echo "stack_volume=$STACK_WORKER_VOLUME_NAME;"
     echo "stack_volume_template=$STACK_WORKER_VOLUME_TEMPLATE;"
     echo "stack_volume_param=$STACK_WORKER_VOLUME_PARAM;"
     echo "stack_infra=$STACK_WORKER_NAME;"
     echo "stack_infra_template=$STACK_WORKER_TEMPLATE;"
     echo "stack_infra_param=$STACK_WORKER_PARAM;"
   ;;
   worker-AZ1) ret=0;
     echo "stack_fip=$STACK_FIP_WORKER_AZ1_NAME;"
     echo "stack_fip_template=$STACK_FIP_WORKER_AZ1_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_WORKER_AZ1_PARAM;"
     echo "stack_volume=$STACK_WORKER_VOLUME_NAME;"
     echo "stack_volume_template=$STACK_WORKER_VOLUME_TEMPLATE;"
     echo "stack_volume_param=$STACK_WORKER_VOLUME_PARAM;"
     echo "stack_infra=$STACK_WORKER_AZ1_NAME;"
     echo "stack_infra_template=$STACK_WORKER_AZ1_TEMPLATE;"
     echo "stack_infra_param=$STACK_WORKER_AZ1_PARAM;"
   ;;
   worker-AZ2) ret=0;
     echo "stack_fip=$STACK_FIP_WORKER_AZ2_NAME;"
     echo "stack_fip_template=$STACK_FIP_WORKER_AZ2_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_WORKER_AZ2_PARAM;"
     echo "stack_volume=$STACK_WORKER_VOLUME_NAME;"
     echo "stack_volume_template=$STACK_WORKER_VOLUME_TEMPLATE;"
     echo "stack_volume_param=$STACK_WORKER_VOLUME_PARAM;"
     echo "stack_infra=$STACK_WORKER_AZ2_NAME;"
     echo "stack_infra_template=$STACK_WORKER_AZ2_TEMPLATE;"
     echo "stack_infra_param=$STACK_WORKER_AZ2_PARAM;"
   ;;
   worker-AZ3) ret=0;
     echo "stack_fip=$STACK_FIP_WORKER_AZ3_NAME;"
     echo "stack_fip_template=$STACK_FIP_WORKER_AZ3_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_WORKER_AZ3_PARAM;"
     echo "stack_volume=$STACK_WORKER_VOLUME_NAME;"
     echo "stack_volume_template=$STACK_WORKER_VOLUME_TEMPLATE;"
     echo "stack_volume_param=$STACK_WORKER_VOLUME_PARAM;"
     echo "stack_infra=$STACK_WORKER_AZ3_NAME;"
     echo "stack_infra_template=$STACK_WORKER_AZ3_TEMPLATE;"
     echo "stack_infra_param=$STACK_WORKER_AZ3_PARAM;"
   ;;
   stack-deployer-AZ1) ret=0;
     echo "stack_fip=$STACK_FIP_STACK_DEPLOYER_AZ1_NAME;"
     echo "stack_fip_template=$STACK_FIP_STACK_DEPLOYER_AZ1_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_STACK_DEPLOYER_AZ1_PARAM;"
     echo "stack_volume=$STACK_STACK_DEPLOYER_VOLUME_NAME;"
     echo "stack_volume_template=$STACK_STACK_DEPLOYER_VOLUME_TEMPLATE;"
     echo "stack_volume_param=$STACK_STACK_DEPLOYER_VOLUME_PARAM;"
     echo "stack_infra=$STACK_STACK_DEPLOYER_AZ1_NAME;"
     echo "stack_infra_template=$STACK_STACK_DEPLOYER_AZ1_TEMPLATE;"
     echo "stack_infra_param=$STACK_STACK_DEPLOYER_AZ1_PARAM;"
   ;;

   lb-blue) ret=0
     echo "stack_fip=$STACK_FIP_LB_NAME;"
     echo "stack_fip_template=$STACK_FIP_LB_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_LB_PARAM;"
     echo "stack_infra=$STACK_LB_NAME;"
     echo "stack_infra_template=$STACK_LB_TEMPLATE;"
     echo "stack_infra_param=$STACK_LB_BLUE_PARAM;"
   ;;
   lb-green) ret=0
     echo "stack_fip=$STACK_FIP_LB_NAME;"
     echo "stack_fip_template=$STACK_FIP_LB_TEMPLATE;"
     echo "stack_fip_param=$STACK_FIP_LB_PARAM;"
     echo "stack_infra=$STACK_LB_NAME;"
     echo "stack_infra_template=$STACK_LB_TEMPLATE;"
     echo "stack_infra_param=$STACK_LB_GREEN_PARAM;"
   ;;
   lb) ret=0
     echo "stack_infra=$STACK_LB_NAME;"
     echo "stack_infra_template=$STACK_LB_TEMPLATE;"
     echo "stack_infra_blue_param=$STACK_LB_BLUE_PARAM;"
     echo "stack_infra_green_param=$STACK_LB_GREEN_PARAM;"
   ;;
   *) log_error 1 "ERROR: type inconnu" ; ret=1
  esac
  return $ret
}

function get_lb_last_state(){
  echo "# get_lb_last_state $@"
  local stack_name=$1
  ret=1
  openstack $openstack_args stack show $stack_name -f json | jq  ".|{ color: .parameters.color, servers_admin: .parameters.servers_admin, servers_candidat: .parameters.servers_candidat }"
  ret=$?
  return $ret
}


function is_lb_last_stack_color_blue(){
  echo "# is_lb_last_stack_color_blue $@"
  local stack_name=$1
  ret=1
  local last_color=$(openstack $openstack_args stack show $stack_name -f json | jq -r .parameters.color)
  echo "# Current lb color: $last_color"
  [ "$last_color" == "blue" ] && ret=0
  return $ret
}

function stack_create_lb(){
  echo "# stack_create_lb $@"
  local next_stack_color=lb-$1
  local parameter=$2

  eval $(get_param_stack_color ${next_stack_color})
  stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone $parameter
  stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone $parameter
  return $?
}

function stack_update_lb(){
  echo "# stack_update_lb $@"
  local next_stack_color=lb-$1
  local parameter=$2

  eval $(get_param_stack_color ${next_stack_color})
  stack_check $stack_infra
  stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone $parameter
  stack_update $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone $parameter
  return $?
}
