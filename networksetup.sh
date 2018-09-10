#!/bin/bash
export PTH=$PWD
cd $PTH/immutableEHR_Patients/scripts

./fabric-network-temp.sh -m down -e af -s qer -b couchdb
cd $PTH/immutableEhr_Xyzhospitals/scripts
 ./neworg.sh -m down -e af -s qer

./fabric-network-temp.sh -m build -e mnb -s fgh -b couchdb

sleep 10

cd $PTH/immutableEhr_Xyzhospitals/scripts
 ./neworg.sh -m generate -e mnb -s fgh -b couchdb
cp ../channel-artifacts/XyzHospitals.json $PTH/immutableEHR_Patients/channel-artifacts/
cp  -rf $PTH/immutableEHR_Patients/channel-artifacts/crypto-config/ordererOrganizations/ ../channel-artifacts/crypto-config/
cd $PTH/immutableEHR_Patients/scripts
 ./addingorg.sh -m addorg -o XyzHospitals -s qwe -c immutableehr
sleep 5
cd $PTH/immutableEhr_Xyzhospitals/scripts
./neworg.sh -m join -c immutableehr  -e asd -s qwe -n mycc -v 3.0
cd $PTH/immutableEHR_Patients/scripts
./addingorg.sh -m upgradechaincode -o XyzHospitals -s qwe -c immutableehr -n mycc -v 2.0

