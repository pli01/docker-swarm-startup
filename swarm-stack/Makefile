STACK = traefik
export STACK
${STACK}-deploy:
	( cd ${STACK} && docker stack deploy --compose-file=${STACK}-stack.yml --with-registry-auth ${STACK} ) && ( docker stack ps ${STACK} )
${STACK}-rm:
	( docker stack ps ${STACK} || true ) && ( docker stack rm ${STACK} )
