#!/bin/bash

DOMAIN="$1"
CHANNEL_NAME="$2"
CHAINCODENAME="$3"
VERSION=$4
: ${CHANNEL_NAME:="immutableehr"}
: ${CHAINCODENAME:="mycc"}
: ${LANGUAGE:="golang"}
: ${VERSION:="2.0"}
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
echo "$DOMAIN"
CC_SRC_PATH="github.com/chaincode/chaincode_example02/go/"
echo $VERSION
# verify the result of the end-to-end test
verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED ==========="
		echo
   		exit 1
	fi
}
## Sometimes Join takes time hence RETRY at least for 5 times
joinChannelWithRetry () {

        set -x
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
        set +x
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "peer0.${DOMAIN} failed to join the channel, Retry after $DELAY seconds"
		sleep 3
		joinChannelWithRetry 
	else
		COUNTER=1
	fi
	verifyResult $res "After $MAX_RETRY attempts, peer0.${DOMAIN} has failed to Join the Channel"
}
installChaincode () {
	
        set -x
	peer chaincode install -n $CHAINCODENAME -v ${VERSION}  -p ${CC_SRC_PATH} >&log.txt
	res=$?
        set +x
	cat log.txt
    if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "peer0.${DOMAIN} failed to join the channel, Retry after $DELAY seconds"
		sleep 3
		installChaincode 
	else
		COUNTER=1
	fi
	verifyResult $res "Chaincode installation on peer0.${DOMAIN} has Failed"
	echo "===================== Chaincode is installed on peer0.${DOMAIN} ===================== "
	echo
}

set -x
peer channel fetch 0 ${CHANNEL_NAME}.block -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
set +x
res=$?
verifyResult $res "Failed to fetch channel block"

joinChannelWithRetry
sleep 1
installChaincode
exit 0