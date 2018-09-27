#!/bin/bash
DOMAIN=heelo
SSH_ADDRESS=sandeep@192.168.1.147
echo " ${DOMAIN} specific configuration is not found"
read -p "${DOMAIN} ssh address :" SSH_ADDRESS 
scp -r ../channel-artifacts/crypto-config/ordererOrganizations/ ${SSH_ADDRESS}:./
scp ${SSH_ADDRESS}:./heelo.txt ./
#scp ./${DOMAIN}.txt composer@192.168.1.158:./immutableEhr/ ;exit
