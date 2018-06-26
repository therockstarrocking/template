#to generate the certificates that will be used for your network configuration

    ``` ../bin/cryptogen generate --config=./crypto-config.yaml```
    
# add AbcInsurer.json 
export FABRIC_CFG_PATH=$PWD && ../bin/configtxgen -printOrg AbcInsurerMSP > AbcInsurer.json



# Adding insurer to network 

export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem && export CHANNEL_NAME=immutableehr

peer channel fetch 0 immutableehr.block -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA


peer channel join -b immutableehr.block

peer chaincode install -n mycc -v 2.0 -p github.com/chaincode/chaincode_example02/go/
