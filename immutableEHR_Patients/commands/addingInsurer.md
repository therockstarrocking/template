export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem  && export CHANNEL_NAME=immutableehr

peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

apt-get -y update && apt-get -y install jq

configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"XyzHospitalsMSP":.[1]}}}}}' config.json ./channel-artifacts/XyzHospitals.json > modified_config.json

configtxlator proto_encode --input config.json --type common.Config --output config.pb

configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb

configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output XyzHospitals_update.pb

configtxlator proto_decode --input XyzHospitals_update.pb --type common.ConfigUpdate | jq . > XyzHospitals_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"immutableehr", "type":2}},"data":{"config_update":'$(cat XyzHospitals_update.json)'}}}' | jq . > XyzHospitals_update_in_envelope.json

configtxlator proto_encode --input XyzHospitals_update_in_envelope.json --type common.Envelope --output XyzHospitals_update_in_envelope.pb

peer channel signconfigtx -f XyzHospitals_update_in_envelope.pb

peer channel update -f XyzHospitals_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA

peer chaincode install -n mycc -v 2.0 -p github.com/chaincode/chaincode_example02/go/

peer chaincode upgrade -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -v 2.0 -c '{"Args":["init","a","900","b","21"]}' -P "OR ('PatientsMSP.peer','XyzHospitalsMSP.peer')"

peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}'



## in XyzHospitals cli 

export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem && export CHANNEL_NAME=immutableehr

peer channel fetch 0 immutableehr.block -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA


peer channel join -b immutableehr.block

peer chaincode install -n mycc -v 2.0 -p github.com/chaincode/chaincode_example02/go/



