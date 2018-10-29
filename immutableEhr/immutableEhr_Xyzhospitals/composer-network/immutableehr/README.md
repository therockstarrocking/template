

composer archive create -t dir -n .


composer network install --card PeerAdmin@hlfv1 --archiveFile immutableehr@0.1.26.bna



composer network start --networkName immutableehr --networkVersion 0.1.26 --networkAdmin admin --networkAdminEnrollSecret adminpw --card PeerAdmin@hlfv1 --file networkadmin.card

composer card import --file networkadmin.card

composer network ping --card admin@immutableehr


composer-rest-server -c admin@immutableehr -n never -w true -p 3100



 
updating the assets 

composer network install -a immutableehr@0.1.28.bna  -c PeerAdmin@hlfv1

composer network upgrade -c PeerAdmin@hlfv1 -n immutableehr  -V 0.1.28

composer-rest-server -c admin@immutableehr -n never
 

composer-rest-server -c alice@immutableehr  -n never -p 4000 
 
for generating composer rest api


yo hyperledger-composer
