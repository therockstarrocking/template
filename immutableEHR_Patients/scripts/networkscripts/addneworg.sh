#!/bin/bash
CHANNEL_NAME=$2
DOMAIN=$1
echo $DOMAIN
export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem 
export CHANNEL_NAME=$CHANNEL_NAME

peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
which jq
  if [ "$?" -ne 0 ]; then
    echo "Installing jq"
    apt-get -y update && apt-get -y install jq
    else
        echo "$?"
  fi

configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"'$DOMAIN'MSP":.[1]}}}}}' config.json ./channel-artifacts/${DOMAIN}.json > modified_config.json

configtxlator proto_encode --input config.json --type common.Config --output config.pb

configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb

configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output ${DOMAIN}_update.pb

configtxlator proto_decode --input ${DOMAIN}_update.pb --type common.ConfigUpdate | jq . > ${DOMAIN}_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat ${DOMAIN}_update.json)'}}}' | jq . > ${DOMAIN}_update_in_envelope.json

configtxlator proto_encode --input ${DOMAIN}_update_in_envelope.json --type common.Envelope --output ${DOMAIN}_update_in_envelope.pb

peer channel signconfigtx -f ${DOMAIN}_update_in_envelope.pb

peer channel update -f ${DOMAIN}_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA 2>&1
if [ $? -ne 0 ];then
  echo "******************** FAILED TO ADD $DOMAIN INTO THE NETWORK *********************"
else
  echo "******************** $DOMAIN ORGANISATION ADDED TO NETWORK **********************"