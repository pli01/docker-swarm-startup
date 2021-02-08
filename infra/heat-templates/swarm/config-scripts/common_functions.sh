# Send success status to OpenStack WaitCondition
function notify_success() {
    unset http_proxy
    unset https_proxy
    unset no_proxy

    $wc_notify --data-binary \
               "{\"status\": \"SUCCESS\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 0
}

# Send success status to OpenStack WaitCondition
function notify_failure() {
    unset http_proxy
    unset https_proxy
    unset no_proxy

    $wc_notify --data-binary \
               "{\"status\": \"FAILURE\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 1
}

function swarm_notify_success() {
    unset http_proxy
    unset https_proxy
    unset no_proxy

    $wc_notify --data-binary \
               "{\"status\": \"SUCCESS\", \"id\": \"$1\", \"data\": \"$2\"}"
}

function swarm_notify_failure() {
    unset http_proxy
    unset https_proxy
    unset no_proxy

    $wc_notify --data-binary \
               "{\"status\": \"FAILURE\", \"id\": \"$1\", \"data\": \"$2\"}"
    exit 1
}


# Wait network up
function wait_network_up(){
i=0 ; until wget -q -O /dev/null http://169.254.169.254/latest/meta-data/local-hostname ; do logger 'wait http://169.254.169.254/latest/meta-data/local-hostname'; sleep 1 ;  let i=i+1 ; [ $i -gt 180 ] && exit 1 ; done
return 0
}
