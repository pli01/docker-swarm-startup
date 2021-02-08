# Provision swarm cluster
## Deploy Leader
```
make deploy-test DRY_RUN=eval  DEPLOY_LEADER="true"
```
## Deploy Manager
```
make deploy-test DRY_RUN=eval  DEPLOY_LEADER="true" DEPLOY_MANAGER="true"
```
## Deploy Worker
```
make deploy-test DRY_RUN=eval  DEPLOY_LEADER="true" DEPLOY_MANAGER="true" DEPLOY_WORKER="true" 
```

# Add workers AZ
```
# on openstack
scale_up_url=$(openstack stack output show swarm-worker-AZX-test  scale_up_url -c output_value -f value)
curl -X POST ${scale_down_url}
```

# Remove workers AZ
## Drain worker on leader
```
# on leader
docker node update --availability drain swarm-worker-az1-test-worker-k4rjqm2gkbvw
```
## Delete worker
## First option: Delete workers stack with all workers from AZ
```
# on openstack
stack delete -y --wait swarm-worker-AZ1-test
make deploy-test DRY_RUN=eval  DEPLOY_LEADER="true" DEPLOY_MANAGER="true" DEPLOY_WORKER="true" 
```

## Second option: Scale down workers stack
```
# on openstack
scale_dn_url=$(openstack stack output show swarm-worker-AZX-test  scale_dn_url -c output_value -f value)
curl -X POST ${scale_down_url}
```

## Remove worker from swarm cluster
```
# on leader
docker node rm swarm-worker-az1-test-worker-k4rjqm2XXXX
```

