#!/bin/bash

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Building Initial channel and adding An Organisation"
echo
# set all variables in .env file as environmental variables
set -o allexport
source ../.env
set +o allexport
#
CHANNEL_NAME="$1"
DELAY="$2"
TIMEOUT="$3"
DOMAIN="$4"
CC_VERSION="$5"
ORDERER_TYPE="$6"
: ${CHANNEL_NAME:="immutableehr"}
: ${DELAY:="3"}
: ${TIMEOUT:="10"}
LANGUAGE="node"
COUNTER=1
MAX_RETRY=5
INS_RETRY=3
if [ "$ORDERER_TYPE" == "kafka" ];then
    echo "KAFKA"
    ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer0.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    ORDERER_URL=orderer0.example.com
    else
    echo "NOT KAFKA"
    ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    ORDERER_URL=orderer.example.com
fi

CC_SRC_PATH=/opt/gopath/src/github.com/chaincode/chaincode_example02/node/
#
setGlobals () {
	PEER=$1
    CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${DOMAIN}.example.com/peers/peer0.${DOMAIN}.example.com/tls/ca.crt
	CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${DOMAIN}.example.com/users/Admin@${DOMAIN}.example.com/msp
    if [ $PEER -eq 0 ]; then
        CORE_PEER_ADDRESS=peer0.$DOMAIN.example.com:7051
    else
        CORE_PEER_ADDRESS=peer1.$DOMAIN.example.com:7051
    fi

}

# verify the results
verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
        echo "========= ERROR !!! FAILED to execute ==========="
		echo
   		exit 1
	fi
}
joinChannelWithRetry () {
    setGlobals $peer
    set -x
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
    set +x
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "peer${peer}.${DOMAIN}.exapmle.com failed to join the channel, Retry after $DELAY seconds"
		sleep $DELAY
		joinChannelWithRetry $peer 
	else
		COUNTER=1
	fi
	verifyResult $res "After $MAX_RETRY attempts, peer${peer}.${DOMAIN}.exapmle.com has failed to Join the Channel"
}
createChannelWithRetry () {
    setGlobals $peer
    set -x
    peer channel create -o $ORDERER_URL:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls --cafile $ORDERER_CA >log.tx
    res=$?
    set -x
    cat log.tx
    if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "peer${peer}.${DOMAIN}.exapmle.com failed to create channel, Retry after $DELAY seconds"
		sleep $DELAY
		createChannelWithRetry $peer 
	else
		COUNTER=1
	fi
    verifyResult $res "${CHANNEL_NAME} Channel creation failed"
    echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
    echo
}
updateAnchorWithRetry () {
    setGlobals $peer
    set -x
    peer channel update -o $ORDERER_URL:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${DOMAIN}MSPanchors.tx --tls --cafile $ORDERER_CA >log.tx
    res=$?
    set -x
    cat log.tx
    if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "peer${peer}.${DOMAIN}.exapmle.com failed to update anchor Peer, Retry after $DELAY seconds"
		sleep $DELAY
		updateAnchorWithRetry $peer 
	else
		COUNTER=1
	fi
    verifyResult $res "peer${peer}.${DOMAIN}.exapmle.com failed to update anchor Peer"
    echo "===================== peer${peer}.${DOMAIN}.exapmle.com updated anchor Peer successfully ===================== "
    echo
}

installChaincodeWithRetry () {
    setGlobals $peer 
    set -x
	peer chaincode install -n mycc -v ${CC_VERSION} -l ${LANGUAGE} -p ${CC_SRC_PATH} >&log.txt
	res=$?
    set +x
	cat log.txt
    if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "Chaincode installation on peer${peer}.${DOMAIN}.exapmle.com has Failed, Retry after $DELAY seconds"
		sleep $DELAY
		installChaincodeWithRetry $peer 
	else
		COUNTER=1
	fi
	verifyResult $res "Chaincode installation on peer${peer}.${DOMAIN}.exapmle.com has Failed"
	echo "===================== Chaincode is installed on peer${peer}.${DOMAIN}.exapmle.com ===================== "
	echo
}
instantiatedWithRetry () {
    setGlobals $peer 
    set -x
    peer chaincode instantiate -o $ORDERER_URL:7050 --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -v ${CC_VERSION} -c '{"Args":["init","a", "100", "b","200"]}'
    res=$?
    set +x
    cat log.txt
    if [ $res -ne 0 -a $COUNTER -lt $INS_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "Chaincode instantiation on peer0.${DOMAIN}.exapmle.com on channel '$CHANNEL_NAME' failed, Retry after $DELAY seconds"
		sleep $DELAY
		instantiatedWithRetry $peer 
	else
		COUNTER=1
	fi
    verifyResult $res "Chaincode instantiation on peer0.${DOMAIN}.exapmle.com on channel '$CHANNEL_NAME' failed"
    echo "===================== Chaincode Instantiation on peer0.${DOMAIN}.exapmle.com on channel '$CHANNEL_NAME' is successful ===================== "
    echo
}
chainQuery () {
    sleep 10
    set -x
    peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >&log.txt
    res=$?
    set +x
    cat log.txt
    EXPECTED_RESULT=100
    if [ $res -ne 0 -a $COUNTER -lt $INS_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "Chaincode query on channel '$CHANNEL_NAME' failed, Retry after $DELAY seconds"
		sleep $DELAY
		chainQuery 
    else
        COUNTER=1
    fi
    if [ $res -eq 0 ]; then
        VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
        if [ "$VALUE" == "$EXPECTED_RESULT" ]; then
            echo "======= Expected value  -  Returned Value =========="
            echo "======= ${EXPECTED_RESULT}             -  ${VALUE}            =========="
            echo
            echo "======= SUCCESFULLY INSTANTIATED CHAINCODE ON  CHANNEL ${CHANNEL_NAME} =========="
            exit 0
        else
            echo "Expected ${EXPECTED_RESULT} but got ${VALUE}"
            echo "!!!!!!!!!!... FAILED...!!!!!!!!!!"
            exit 1
        fi
    fi
}

# Channel creation 
echo
echo "========== Channel ${CHANNEL_NAME} creation started =========="
echo
#sleep 5
sleep 10
createChannelWithRetry
#sleep 10
#
# Join Channel
echo "========== Peers  Joining channel started =========="
for peer in 0 1; do
    #sleep 30
    joinChannelWithRetry $peer 
    echo "===================== peer${peer}.${DOMAIN}.exapmle.com joined on the channel \"$CHANNEL_NAME\" ===================== "
    sleep $DELAY
    echo
done
##sleep 10
#
# Update Anchor peer 
echo "========== Updating Anchor peer ========="
#sleep 10
updateAnchorWithRetry 0
#
# Chaincode installation
echo "========== Chaincode installation started ========== "
for peer in 0 1; do
    #sleep 10
    installChaincodeWithRetry $peer 
    sleep $DELAY
    echo
done
#sleep 10
#
# Instantiation 
echo "========== Instantiation on ${CHANNEL_NAME} STARTED ========="
sleep 5
instantiatedWithRetry 0
sleep 20
#
# Query 
echo "========== Attempting to Query peer0.${DOMAIN}.exapmle.com ...$(($(date +%s)-starttime)) secs =========="
chainQuery
exit 0