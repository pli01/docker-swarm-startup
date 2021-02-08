##############################################
# WARNING : THIS FILE SHOULDN'T BE TOUCHED   #
#    FOR ENVIRONNEMENT CONFIGURATION         #
# CONFIGURABLE VARIABLES SHOULD BE OVERRIDED #
# IN THE 'artifacts' FILE, AS NOT COMMITTED  #
##############################################
deploy-debug:
	STACK_HTTP_PROXY_DELETE="$${STACK_HTTP_PROXY_DELETE}" \
	STACK_INFRA_DELETE="$${STACK_INFRA_DELETE}" \
          DRY_RUN="$${DRY_RUN}" \
          CREATE_IF_NOT_EXIST="$${CREATE_IF_NOT_EXIST}" \
          openstack_args="$${openstack_args}" \
          bash tools/deploy.sh debug

deploy-test:
	STACK_HTTP_PROXY_DELETE="$${STACK_HTTP_PROXY_DELETE}" \
	STACK_INFRA_DELETE="$${STACK_INFRA_DELETE}" \
          DRY_RUN="$${DRY_RUN}" \
          CREATE_IF_NOT_EXIST="$${CREATE_IF_NOT_EXIST}" \
          openstack_args="$${openstack_args}" \
          bash tools/deploy.sh test

deploy-dev:
	STACK_HTTP_PROXY_DELETE="$${STACK_HTTP_PROXY_DELETE}" \
	STACK_INFRA_DELETE="$${STACK_INFRA_DELETE}" \
          DRY_RUN="$${DRY_RUN}" \
          CREATE_IF_NOT_EXIST="$${CREATE_IF_NOT_EXIST}" \
          openstack_args="$${openstack_args}" \
          bash tools/deploy.sh dev

deploy-qualif:
	STACK_HTTP_PROXY_DELETE="$${STACK_HTTP_PROXY_DELETE}" \
	STACK_INFRA_DELETE="$${STACK_INFRA_DELETE}" \
          DRY_RUN="$${DRY_RUN}" \
          CREATE_IF_NOT_EXIST="$${CREATE_IF_NOT_EXIST}" \
          openstack_args="$${openstack_args}" \
          bash tools/deploy.sh qualif

deploy-prod:
	STACK_HTTP_PROXY_DELETE="$${STACK_HTTP_PROXY_DELETE}" \
	STACK_INFRA_DELETE="$${STACK_INFRA_DELETE}" \
          DRY_RUN="$${DRY_RUN}" \
          CREATE_IF_NOT_EXIST="$${CREATE_IF_NOT_EXIST}" \
          openstack_args="$${openstack_args}" \
          bash tools/deploy.sh prod

deploy-prod-int:
	STACK_HTTP_PROXY_DELETE="$${STACK_HTTP_PROXY_DELETE}" \
	STACK_INFRA_DELETE="$${STACK_INFRA_DELETE}" \
          DRY_RUN="$${DRY_RUN}" \
          CREATE_IF_NOT_EXIST="$${CREATE_IF_NOT_EXIST}" \
          openstack_args="$${openstack_args}" \
          bash tools/deploy.sh prod-int

deploy-acl-swift-test:
	DRY_RUN="$${DRY_RUN}" \
	bash -x tools/swift-acl.sh test

deploy-acl-swift-dev:
	DRY_RUN="$${DRY_RUN}" \
	bash tools/swift-acl.sh dev

deploy-acl-swift-prod:
	DRY_RUN="$${DRY_RUN}" \
	bash tools/swift-acl.sh prod

deploy-acl-swift-qualif:
	DRY_RUN="$${DRY_RUN}" \
	bash tools/swift-acl.sh qualif

deploy-acl-swift-prod-int:
	DRY_RUN="$${DRY_RUN}" \
	bash tools/swift-acl.sh prod-int


