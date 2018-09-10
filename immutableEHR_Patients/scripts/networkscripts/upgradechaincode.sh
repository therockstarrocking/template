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
setGlobals () {
	PEER=$1
	if [ $PEER -eq 0 ]; then
        CORE_PEER_ADDRESS=peer0.Patients.example.com:7051
    else
        CORE_PEER_ADDRESS=peer1.Patients.example.com:7051
    fi
}
verifyResult () {
	if [ $1 -ne 0 ] ; then
    STATUS=$(echo $2| grep 500)
    echo $STATUS
    if [ $STATUS != "" ]; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
        echo "========= ERROR !!! FAILED==========="
		echo
   		exit 1
    fi

	fi
}
installChaincode () {
	PEER=$1
    setGlobals $PEER
        set -x
	peer chaincode install -n $CHAINCODENAME -v $VERSION -p ${CC_SRC_PATH} >&log.txt
	res=$?
        set +x
	cat log.txt
    if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "peer${PEER}.${DOMAIN} failed to install chaincode, Retry after $DELAY seconds"
		sleep 3
		installChaincode $PEER
	else
		COUNTER=1
	fi
	verifyResult $res "Chaincode installation on peer0.${DOMAIN} has Failed"
	echo "===================== Chaincode is installed on peer${PEER}.${DOMAIN} ===================== "
	echo
}
upgradeChaincode () {
	PEER=$1
    setGlobals $PEER
        set -x
	peer chaincode upgrade -o orderer.example.com:7050 --tls  --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODENAME -v ${VERSION} -c '{"Args":["init","a","30","b","70"]}' -P "OR ('PatientsMSP.peer','${DOMAIN}MSP.peer')" >&log.txt
	res=$?
        set +x
	cat log.txt
    if [ $res -ne 0 -a $COUNTER -lt 3 ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "peer0.${DOMAIN} failed upgrade chaincode, Retry after $DELAY seconds"
		sleep 3
		upgradeChaincode $PEER
	else
		COUNTER=1
	fi
	verifyResult $res "upgrading chaincode  has Failed"
	echo "===================== Chaincode is upgraded ===================== "
	echo
}

chainQuery () {
    sleep 10
    set -x
    peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >&log.txt
    res=$?
    set +x
    cat log.txt
    EXPECTED_RESULT=30
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


installChaincode 0
sleep 1
installChaincode 1
sleep 1
upgradeChaincode
setGlobals 0
chainQuery

exit 0