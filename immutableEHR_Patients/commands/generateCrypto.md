#to generate the certificates that will be used for your network configuration

../../bin/cryptogen generate --config=./crypto-config.yaml
   

export FABRIC_CFG_PATH=$PWD

#Then, we’ll invoke the configtxgen tool to create the orderer genesis block:

../../bin/configtxgen -profile ImmutableEhrOrdererGenesis -outputBlock genesis.block

#The channel.tx artifact contains the definitions for our sample channel

export CHANNEL_NAME=immutableehr  && ../../bin/configtxgen -profile ImmutableEhrChannel -outputCreateChannelTx channel.tx -channelID $CHANNEL_NAME

#Creating Anchor peer .tx files

../../bin/configtxgen -profile ImmutableEhrChannel -outputAnchorPeersUpdate PatientsMSPanchors.tx -channelID $CHANNEL_NAME -asOrg PatientsMSP


export CORE_PEER_ADDRESS=peer1.Patients.example.com:7051

ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

export CHANNEL_NAME=immutableehr && peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx 


export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem  && export CHANNEL_NAME=immutableehr

peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls --cafile $ORDERER_CA

peer channel join -b immutableehr.block

peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/PatientsMSPanchors.tx --tls --cafile $ORDERER_CA

peer chaincode install -n mycc -v 1.0 -l node -p /opt/gopath/src/github.com/chaincode/chaincode_example02/node/

peer chaincode instantiate -o orderer.example.com:7050 --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a", "100", "b","200"]}' -P "AND ('PatientsMSP.peer')"

peer chaincode invoke -o orderer.example.com:7050 --tls true --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","30"]}'

peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}'


export CORE_PEER_ADDRESS=peer1.Patients.example.com:7051





