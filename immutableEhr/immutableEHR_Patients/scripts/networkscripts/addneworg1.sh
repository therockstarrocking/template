#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# This script is designed to be run in the ${DOMAIN}cli container as the
# first step of the EYFN tutorial.  It creates and submits a
# configuration transaction to add ${DOMAIN} to the network previously
# setup in the BYFN tutorial.
#
DOMAIN="$1"
CHANNEL_NAME="$2"
DELAY="$3"
TIMEOUT="$4"
: ${CHANNEL_NAME:="immutableehr"}
: ${DELAY:="3"}
: ${LANGUAGE:="golang"}
: ${TIMEOUT:="10"}
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
echo "$DOMAIN"
CC_SRC_PATH="github.com/chaincode/chaincode_example02/go/"
if [ "$LANGUAGE" = "node" ]; then
	CC_SRC_PATH="/opt/gopath/src/github.com/chaincode/chaincode_example02/node/"
fi

#CHANNEL_NAME="immutableehr"
echo
echo "========= Creating config transaction to add ${DOMAIN} to network =========== "
echo
which jq
  if [ "$?" -ne 0 ]; then
    echo "Installing jq"
    apt-get -y update && apt-get -y install jq
    else
        echo "$?"
  fi


verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
		echo
   		exit 1
	fi
}
setOrdererGlobals() {
        CORE_PEER_LOCALMSPID="OrdererMSP"
        CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
        CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp
}
setGlobals () {
	PEER=$1
	if [ $PEER -eq 0 ]; then
        CORE_PEER_ADDRESS=peer0.Patients.example.com:7051
    else
        CORE_PEER_ADDRESS=peer1.Patients.example.com:7051
    fi
    echo $CORE_PEER_ADDRESS
}
# fetchChannelConfig <channel_id> <output_json>
# Writes the current channel config for a given channel to a JSON file
fetchChannelConfig() {
  CHANNEL=$1
  OUTPUT=$2

  setOrdererGlobals

  echo "Fetching the most recent configuration block for the channel"

    set -x
    peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
    set +x
  
  echo "Decoding config block to JSON and isolating config to ${OUTPUT}"
  set -x
  configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > ${OUTPUT}
  set +x
}
# createConfigUpdate <channel_id> <original_config.json> <modified_config.json> <output.pb>
# Takes an original and modified config, and produces the config update tx which transitions between the two
createConfigUpdate() {
  CHANNEL=$1
  ORIGINAL=$2
  MODIFIED=$3
  OUTPUT=$4

  set -x
  configtxlator proto_encode --input ${ORIGINAL} --type common.Config --output config.pb
  set +x
  sleep 1
  set -x
  configtxlator proto_encode --input ${MODIFIED} --type common.Config --output modified_config.pb
  set +x
  sleep 1
  set -x
  configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output ${DOMAIN}_update.pb
  set +x
  sleep 1
  set -x
  configtxlator proto_decode --input ${DOMAIN}_update.pb --type common.ConfigUpdate | jq . > ${DOMAIN}_update.json
  set +x
  sleep 2
  set -x
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat ${DOMAIN}_update.json)'}}}' | jq . > ${DOMAIN}_update_in_envelope.json
  set +x
  sleep 3
  set -x
  configtxlator proto_encode --input ${DOMAIN}_update_in_envelope.json --type common.Envelope --output ${DOMAIN}_update_in_envelope.pb
  set +x
}
# signConfigtxAsPeerOrg <org> <configtx.pb>
# Set the peerOrg admin of an org and signing the cosnfig update
signConfigtxAsPeerOrg() {
        TX=$1
        sleep 1
        set -x
        peer channel signconfigtx -f ${DOMAIN}_update_in_envelope.pb
        set +x
}

# Fetch the config for the channel, writing it to config.json
fetchChannelConfig ${CHANNEL_NAME} config.json

# Modify the configuration to append the new org
sleep 3
set -x
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"'${DOMAIN}'MSP":.[1]}}}}}' config.json ./channel-artifacts/${DOMAIN}.json > modified_config.json
set +x
sleep 1
# Compute a config update, based on the differences between config.json and modified_config.json, write it as a transaction to ${DOMAIN}_update_in_envelope.pb
createConfigUpdate ${CHANNEL_NAME} config.json modified_config.json ${DOMAIN}

echo
echo "========= Config transaction to add ${DOMAIN} to network created ===== "
echo

echo "Signing config transaction"
echo
sleep 2
set -x
signConfigtxAsPeerOrg  ${DOMAIN}_update_in_envelope.pb
set +x
# set -x
# setGlobals 1
# set +x
# set -x
# sleep 2
# signConfigtxAsPeerOrg ${DOMAIN}_update_in_envelope.pb
# set +x
# setGlobals 0
# echo
sleep 3
set -x
peer channel update -f ${DOMAIN}_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA
set +x

echo
echo "========= Config transaction to add ${DOMAIN} to network submitted! =========== "
echo

exit 0
