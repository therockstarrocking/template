#!/bin/bash

#
# Copyright Waleed El Sayed All Rights Reserved.
#

#
# This script builds, deploys or updates the composer network
#

# Grab the current directory
#DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DIR=$PWD
FABRIC_CRYPTO_CONFIG=../channel-artifacts/crypto-config

# set all variables in .env file as environmental variables
set -o allexport
source .env
set +o allexport

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  ./composer-network.sh -m build|deploy|update|start|stop|recreate|addAdminParticipant|createParticipantCard"
  echo "  ./composer-network.sh -h|--help (print this message)"
  echo "    -m <mode> - one of 'build', 'deploy'"
  echo "      - 'build' - build the network"
  echo "      - 'deploy' - deploy the network"
  echo "      - 'upgrade' - upgrade the network"
  echo "      - 'start' - start composer-cli container"
  echo "      - 'stop' - create composer-cli container"
  echo "      - 'recreate' - recreate composer-cli container"
  echo "      - 'addAdminParticipant' - create first user as admin participant"
  echo "      - 'createParticipantCard' - create Card for participant which already exists"
  echo "      - 'upgradeComposer' - upgrade composer and recreate container"

}

# Connection credentials
function verify () {
  if [ $1 -ne 0 ]; then
    echo $2
    exit 1
    else
    echo "=========> $3 <============="
  fi
}
function connectionCredentials () {
  CORG=$1
  FABRIC_CRYPTO_CONFIG=../channel-artifacts/crypto-config
  XFABRIC_CRYPTO_CONFIG=./${DOMAIN2}/ca.crt
  XCA_CRYPTO_CONFIG=../immutableEhr_XyzHospitals/channel-artifacts/crypto-config/peerOrganizations/XyzHospitals.example.com/
  rm -f ${DIR}/./connection.json

  CA2_CERT="$(awk '{printf "%s\\n", $0}' ./${DOMAIN2}/ca.crt)"
  #CA_CERT="$(awk '{printf "%s\\n", $0}' ./ca.crt)"
  CA_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.example.com/peers/peer0.${DOMAIN}.example.com/tls/ca.crt)"
  # verify $? "failed ... try again"
  ORDERER_CERT0="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/ordererOrganizations/example.com/orderers/orderer0.example.com/tls/ca.crt)"
  ORDERER_CERT1="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/ordererOrganizations/example.com/orderers/orderer1.example.com/tls/ca.crt)"
  ORDERER_CERT2="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/ordererOrganizations/example.com/orderers/orderer2.example.com/tls/ca.crt)"
  PCA_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.example.com/ca/ca.${DOMAIN}.example.com-cert.pem)"
  XCA_CERT="$(awk '{printf "%s\\n", $0}' ./${DOMAIN2}/ca.${DOMAIN2}.example.com-cert.pem)"

cat << EOF > ${DIR}/./connection-${CORG}.json
{
  "name": "${COMPOSER_FABRIC_NETWORK_NAME}",
  "x-type": "hlfv1",
  "x-commitTimeout": 300,
  "version": "1.0.0",
  "client": {
    "organization": "${CORG}",
    "connection": {
      "timeout": {
        "peer": {
          "endorser": "300",
          "eventHub": "300",
          "eventReg": "300"
        },
        "orderer": "300"
      }
    }
  },
  "channels": {
    "${CHANNEL_NAME}": {
      "orderers": [
        "orderer0.example.com",
        "orderer1.example.com",
        "orderer2.example.com"
      ],
      "peers": {
        "peer0.${DOMAIN}.example.com": {
          "endorsingPeer": true,
          "chaincodeQuery": true,
          "eventSource": true
        },
        "peer1.${DOMAIN}.example.com": {
          "endorsingPeer": true,
          "chaincodeQuery": true,
          "eventSource": true
        },
        "peer0.${DOMAIN2}.example.com": {
          "endorsingPeer": true,
          "chaincodeQuery": true,
          "eventSource": true
        }
      }
    }
  },
  "organizations": {
    "${DOMAIN}": {
      "mspid": "${DOMAIN}MSP",
      "peers": [
        "peer0.${DOMAIN}.example.com",
        "peer1.${DOMAIN}.example.com"
      ],
      "certificateAuthorities": [
        "ca_peer${DOMAIN}"
      ]
    },
    "${DOMAIN2}": {
      "mspid": "${DOMAIN2}MSP",
      "peers": [
        "peer0.${DOMAIN2}.example.com"
      ],
      "certificateAuthorities": [
        "ca_peer${DOMAIN2}"
      ]
    }
  },
  "orderers": {
    "orderer0.example.com": {
      "url": "grpcs://192.168.1.158:7050",
      "grpcOptions": {
        "ssl-target-name-override": "orderer0.example.com",
        "grpc.keepalive_time_ms": 600000,
        "grpc.max_send_message_length": 15728640,
        "grpc.max_receive_message_length": 15728640
      },
      "tlsCACerts": {
        "pem": "${ORDERER_CERT0}"
      }
    },
    "orderer1.example.com": {
      "url": "grpcs://192.168.1.158:8050",
      "grpcOptions": {
        "ssl-target-name-override": "orderer1.example.com",
        "grpc.keepalive_time_ms": 600000,
        "grpc.max_send_message_length": 15728640,
        "grpc.max_receive_message_length": 15728640
      },
      "tlsCACerts": {
        "pem": "${ORDERER_CERT1}"
      }
    },
    "orderer2.example.com": {
      "url": "grpcs://192.168.1.158:9050",
      "grpcOptions": {
        "ssl-target-name-override": "orderer2.example.com",
        "grpc.keepalive_time_ms": 600000,
        "grpc.max_send_message_length": 15728640,
        "grpc.max_receive_message_length": 15728640
      },
      "tlsCACerts": {
        "pem": "${ORDERER_CERT2}"
      }
    }
  },
  "peers": {
    "peer0.${DOMAIN}.example.com": {
      "url": "grpcs://192.168.1.158:7051",
      "eventUrl": "grpcs://192.168.1.158:7053",
      "grpcOptions": {
        "ssl-target-name-override": "peer0.${DOMAIN}.example.com"
      },
      "tlsCACerts": {
        "pem": "${CA_CERT}"
      }
    },
    "peer1.${DOMAIN}.example.com": {
      "url": "grpcs://192.168.1.158:8051",
      "eventUrl": "grpcs://192.168.1.158:8053",
      "grpcOptions": {
        "ssl-target-name-override": "peer1.${DOMAIN}.example.com"
      },
      "tlsCACerts": {
        "pem": "${CA_CERT}"
      }
    },
    "peer0.${DOMAIN2}.example.com": {
      "url": "grpcs://192.168.1.158:9051",
      "eventUrl": "grpcs://192.168.1.158:9053",
      "grpcOptions": {
        "ssl-target-name-override": "peer0.${DOMAIN2}.example.com"
      },
      "tlsCACerts": {
        "pem": "${CA2_CERT}"
      }
    }
  },
  "certificateAuthorities": {
    "ca_peer${DOMAIN}": {
      "url": "https://192.168.1.158:7054",
      "caName": "ca-${DOMAIN}",
      "httpOptions": {
        "verify": false
      },
      "tlsCACerts": {
        "pem": "${PCA_CERT}"
      }
    },
    "ca_peer${DOMAIN2}": {
      "url": "https://192.168.1.158:8054",
      "caName": "ca-${DOMAIN2}",
      "httpOptions": {
        "verify": false
      },
      "tlsCACerts": {
        "pem": "${XCA_CERT}"
      }
    }
  }
}
EOF
    echo " ============> Succesfullly created connection.json file <==================="
}

# create node container and install composer-cli on it
function buildComposer () {
    domain=$( echo "$DOMAIN" | awk '{print tolower($0)}')
    COMPOSER_IMAGE=$(docker images | grep ${domain}/composer-cli | awk '{print $1}')
    echo $COMPOSER_IMAGE
    if [ ! $COMPOSER_IMAGE ]; then
        cd ${DIR}/docker
        docker build -t ${domain}/composer-cli .
        cd ${DIR}

        rm -rf ${DIR}/.composer
        echo " =========> Succesfully build Composer image => ${domain}/composer-cli <==========="
        else
            echo  " =======> ${domain}/composer-cli , Image already exists <======="
    fi
 }


 function askNetworkName () {
    read -p "Business network name: " COMPOSER_NETWORK_NAME
    if [ -z "$COMPOSER_NETWORK_NAME" ]; then
        echo "Business network not found! Enter Business network name which you defined during building the composer network."
        askNetworkName
    fi
}
function askNetworkVersion () {
    read -p "Business network version: " NETWORK_ARCHIVE_VERSION
    if [ -z "$NETWORK_ARCHIVE_VERSION" ]; then
        echo "Business network VERSION  not found! Enter Business network version which you defined during building the composer network."
        askNetworkVersion
    fi
}
function askAdminName () {
    read -p "Business network admin name: " ADMIN_NAME
    if [ -z "$ADMIN_NAME" ]; then
        echo "Business network  admin name not found! Enter Business network Admin name ."
        askAdminName
    fi
}
function askNewOrgAdminName () {
    read -p "${DOMAIN2} network ADMIN name: " ORG2_ADMIN_NAME
    if [ -z "$ORG2_ADMIN_NAME" ]; then
        echo "Enter ${DOMAIN2} ADMIN name"
        askNewOrgAdminName
    fi
}
function replaceVersionNr () {
    # sed on MacOSX does not support -i flag with a null extension. We will use
    # 't' for our back-up's extension and depete it at the end of the function
    ARCH=`uname -s | grep Darwin`
    if [ "$ARCH" == "Darwin" ]; then
        OPTS="-it"
    else
        OPTS="-i"
    fi

    # change default version
    sed $OPTS 's/"version": "0.0.'${1}'"/"version": "0.0.'${NETWORK_ARCHIVE_VERSION}'"/g' ${COMPOSER_NETWORK_NAME}/package.json
    # If MacOSX, remove the temporary backup of the docker-compose file
    if [ "$ARCH" == "Darwin" ]; then
        rm -rf ${COMPOSER_NETWORK_NAME}/package.jsont
    fi
}
 function createEndorser() {
     Domain1=$1
     Domain2=$2
 }
 function networkStart() {
   CONTAINER_NAME=$(docker ps |grep composer_cli|awk '{print $1}')
   #COMPOSER_NETWORK_NAME=immutableehr
    if [ -z "$COMPOSER_NETWORK_NAME" ]; then
        askNetworkName
    fi
    if [ -z "$NETWORK_ARCHIVE_VERSION" ]; then
        askNetworkVersion
    fi
    if [ -z "$ADMIN_NAME" ]; then
        askAdminName
    fi
    askNewOrgAdminName

    NETWORK_ARCHIVE=./network-archives/${COMPOSER_NETWORK_NAME}@${NETWORK_ARCHIVE_VERSION}.bna

    # Deploy the business network, from COMPOSER_NETWORK_NAME directory
    docker exec ${CONTAINER_NAME} composer network start -c PeerAdmin@immutableehr-${DOMAIN} -n ${COMPOSER_NETWORK_NAME} -V ${NETWORK_ARCHIVE_VERSION} -A ${ADMIN_NAME} -C ./cards/${ADMIN_NAME}/admin-pub.pem -A ${ORG2_ADMIN_NAME} -C ./cards/${ORG2_ADMIN_NAME}/admin-pub.pem
    verify $? "failed to start the network" " Network Started"

    docker exec ${CONTAINER_NAME} composer card create -p ./connection-${DOMAIN}.json -u ${ADMIN_NAME} -n ${COMPOSER_NETWORK_NAME} -c ${ADMIN_NAME}/admin-pub.pem -k ${ADMIN_NAME}/admin-priv.pem -f ./cards/${ADMIN_NAME}@${COMPOSER_NETWORK_NAME}.card
    # Import the network administrator identity as a usable business network card
    docker exec ${CONTAINER_NAME} composer card import --file ./cards/${ADMIN_NAME}@${COMPOSER_NETWORK_NAME}.card

    docker exec ${CONTAINER_NAME} composer card create -p ./connection-${DOMI2}.json -u ${ORG2_ADMIN_NAME} -n ${COMPOSER_NETWORK_NAME} -c ${ORG2_ADMIN_NAME}/admin-pub.pem -k ${ORG2_ADMIN_NAME}/admin-priv.pem -f ./cards/${ORG2_ADMIN_NAME}@${COMPOSER_NETWORK_NAME}.card
    # Import the network administrator identity as a usable business network card
    docker exec ${CONTAINER_NAME} composer card import --file ./cards/${ORG2_ADMIN_NAME}@${COMPOSER_NETWORK_NAME}.card

    echo "Hyperledger Composer admin card has been imported"
    # Show imported cards
    docker exec ${CONTAINER_NAME} composer card list
    docker exec ${CONTAINER_NAME} composer network ping -c ${ADMIN_NAME}@${COMPOSER_NETWORK_NAME}
    docker exec ${CONTAINER_NAME} composer network ping -c ${ORG2_ADMIN_NAME}@${COMPOSER_NETWORK_NAME}
 
    }
function networkInstall() {
  #COMPOSER_NETWORK_NAME=immutableehr
    CONTAINER_NAME=$(docker ps |grep composer_cli|awk '{print $1}')
    #COMPOSER_NETWORK_NAME=immutableehr
    askNetworkName
    askNetworkVersion
    askAdminName
    askNewOrgAdminName

    # Generate a business network archive
    docker exec ${CONTAINER_NAME} composer archive create -t dir -n ${COMPOSER_NETWORK_NAME} -a ./network-archives/${COMPOSER_NETWORK_NAME}@${NETWORK_ARCHIVE_VERSION}.bna

    echo " Composer file : ${COMPOSER_NETWORK_NAME}@${NETWORK_ARCHIVE_VERSION}.bna " 
    # Install the composer network
    docker exec ${CONTAINER_NAME} composer network install --card PeerAdmin@immutableehr-${DOMAIN} --archiveFile ./network-archives/${COMPOSER_NETWORK_NAME}@${NETWORK_ARCHIVE_VERSION}.bna 2>&1
    verify $? " Failed to install chaincode" " Installed chaincode in ${DOMAIN} network"

    # docker exec ${CONTAINER_NAME} composer network install --card PeerAdmin@immutableehr-${DOMAIN2} --archiveFile ./network-archives/${COMPOSER_NETWORK_NAME}@${NETWORK_ARCHIVE_VERSION}.bna 2>&1
    # verify $? " Failed to install chaincode" " Installed chaincode in ${DOMAIN2} network"

    cd ./cards/
  if [ ! -d "${ADMIN_NAME}" ]; then
    mkdir ${ADMIN_NAME}
    #mkdir ${ORG2_ADMIN_NAME}
    docker exec ${CONTAINER_NAME} composer identity request -c PeerAdmin@immutableehr-${DOMAIN} -u admin -s adminpw -d ./cards/${ADMIN_NAME}
    #docker exec ${CONTAINER_NAME} composer identity request -c PeerAdmin@immutableehr-${DOMAIN2} -u admin -s adminpw -d ./cards/${ORG2_ADMIN_NAME}
    cd ../
    #networkStart
    else
      cd ../
  fi
 }
 function getContainerName() {
     CONTAINER_NAME=$(docker ps |grep composer_cli|awk '{print $1}')
     return CONTAINER_NAME
 }

 function createPeerAdmin(){
    CONTAINER_NAME=$(docker ps |grep composer_cli|awk '{print $1}')
    COMPOSER_NETWORK_NAME=immutableehr
    FABRIC_CRYPTO_CONFIG=../channel-artifacts/crypto-config
    #XFABRIC_CRYPTO_CONFIG=./${DOMAIN2}
    # rm -rf ${DOMAIN2}
    rm -f ${CERT_FILE_NAME}
    #mkdir ${DOMAIN2}
    CERT_PATH=${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.example.com/users/Admin@${DOMAIN}.example.com/msp/signcerts/${CERT_FILE_NAME}
    #verify $? "FAILED...TRY AGAIN "
    cp ${CERT_PATH} .

    # XCERT_PATH=${XFABRIC_CRYPTO_CONFIG}/keystore
    # #verify $? "FAILED...TRY AGAIN "
    # cp ${XCERT_PATH} ./${DOMAIN2}/

    PRIVATE_KEY_PATH=${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.example.com/users/Admin@${DOMAIN}.example.com/msp/keystore
    PRIVATE_KEY=$(ls ${PRIVATE_KEY_PATH}/*_sk)
    rm -f *_sk
    cp ${PRIVATE_KEY} .
    PRIVATE_KEY=$(ls *_sk)

    # XPRIVATE_KEY_PATH=${XFABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN2}.example.com/users/Admin@${DOMAIN2}.example.com/msp/keystore
    # XPRIVATE_KEY=$(ls ./${DOMAIN2}/*_sk)

    #cp ${XPRIVATE_KEY} ./${DOMAIN2}/
    #XPRIVATE_KEY=$(ls ./${DOMAIN2}/*_sk)

    FABRIC_NETWORK_PEERADMIN_CARD_NAME=PeeerAdmin@immutableehr
    if docker exec ${CONTAINER_NAME} composer card list -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} > /dev/null; then
        docker exec ${CONTAINER_NAME} composer card delete -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME}
        rm -rf ./cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}
    fi
    docker exec ${CONTAINER_NAME} composer card create -p ./connection-${DOMAIN}.json -u PeerAdmin -c ./Admin@${DOMAIN}.example.com-cert.pem -k ./*_sk -r PeerAdmin -r ChannelAdmin -f ./cards/PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN}.card 2>&1
    verify $? "FAILED...To CREATE PEER ADMIN " "${DOMAIN} PEER ADMIN CARD CREATED SUCCESFULLY"

    # docker exec ${CONTAINER_NAME} composer card create -p ./connection-${DOMAIN2}.json -u PeerAdmin -c ./${DOMAIN2}/Admin@${DOMAIN2}.example.com-cert.pem -k ./${DOMAIN2}/*_sk -r PeerAdmin -r ChannelAdmin -f ./cards/PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN2}.card 2>&1
    # verify $? "FAILED...To CREATE PEER ADMIN " "${DOMAIN} PEER ADMIN CARD CREATED SUCCESFULLY"

    docker exec ${CONTAINER_NAME} composer card import -f ./cards/PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN}.card --card PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN} 2>&1
    verify $? "FAILED...TRY AGAIN " "${DOMAIN} PEER ADMIN CARD IMPORTED"

    # docker exec ${CONTAINER_NAME} composer card import -f ./cards/PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN2}.card --card PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN2} 2>&1
    # verify $? "FAILED...TRY AGAIN " "${DOMAIN2} PEER ADMIN CARD IMPORTED"
    docker exec ${CONTAINER_NAME} composer card list
    networkInstall $CONTAINER_NAME

 }
 function networkBuild() {
   rm -rf ./.composer/cads/
   rm -rf ./.composer/client-data/
   COMPOSER_NETWORK_NAME=immutableehr
    domain=$( echo "$DOMAIN" | awk '{print tolower($0)}')
    if [ ! -f "connection.json" ]; then
        echo "--------------------------- Creating Connection.json ---------------------------- "
        connectionCredentials "${DOMAIN}"
        #connectionCredentials "XyzHospitals"
    fi
    echo " ----------------------------------------- Building Composer Image ------------------------------"
    buildComposer
    ARCH=`uname -s | grep Darwin`
    if [ "$ARCH" == "Darwin" ]; then
        OPTS="-it"
    else
        OPTS="-i"
    fi
    echo " --------------------------- Writing Docker-compose file -----------------------"
    COMPOSE_FILE="docker-compose.yaml"
    # Copy the template to the file that will be modified to add the domain name and External network
    cp ./template-files/docker-compose-template.yaml ${COMPOSE_FILE}
    sed $OPTS "s/DOMAIN/${domain}/g" "${COMPOSE_FILE}"
    sed $OPTS "s/EXTERNAL_NETWORK/${EXTERNAL_NETWORK}/g" "$COMPOSE_FILE"
    if [ -f "docker-compose.yaml" ]; then
        echo " ========> docker compose file created "
    fi
    echo " ------------------------------ Deploying composer cli -----------------------------------"
    docker stack deploy ${DOCKER_STACK_NAME} -c $COMPOSE_FILE 2>&1
    sleep 60
    CONTAINER_NAME=$(docker ps |grep composer_cli|awk '{print $1}')
    echo $CONTAINER_NAME
    # if [ -z ${CONTAINER_NAME} ]; then
        echo "container created at id ===>  ${CONTAINER_NAME}"
        createPeerAdmin $CONTAINER_NAME
    #     else 
    #     echo $CONTAINER_NAME
    #     echo " container not created"
    # fi

 }

 #functioncreate
# runStack () {
#   if [ -n STACK_NAME ]; then
#     read -p "enter stack name : " STACK_NAME
#   fi
#   cp .template-files/docker-compose-template.yaml docker-compose.yaml
#   sed 
#   docker stack deploy $STACK_NAME -c docker-compose.yaml
# }

# # recreate node container and install composer-cli on it
# function recreateComposer () {
#     docker stop ${COMPOSER_CONTAINER_NAME} || true && docker rm -f ${COMPOSER_CONTAINER_NAME} || true

#     docker run \
#         -d \
#         -it \
#         -e TZ=${TIME_ZONE} \
#         -w ${COMPOSER_WORKING_DIR} \
#         -v ${DIR}:${COMPOSER_WORKING_DIR} \
#         -v ${DIR}/.composer:/root/.composer \
#         --name ${COMPOSER_CONTAINER_NAME} \
#         --network ${FABRIC_DOCKER_NETWORK_NAME} \
#         --restart=always \
#         -p 9090:9090 \
#         ${DOMAIN}/composer-cli
# }

# # build
# function networkBuild () {

#     # create node container and install composer-cli on it
#     buildComposer

#     if [ -d "$FABRIC_CRYPTO_CONFIG" ]
#         then
#             rm -rf ./fabric-network/crypto-config
#             ln -s ../${FABRIC_CRYPTO_CONFIG}/ fabric-network/
#         else
#             echo "Fabric crypto-config not found! Please run './fabric-network.sh -m build' in fabric directory"
#             exit
#     fi

#     rm -f ./cards/*.card

#     connectionCredentials

#     rm -f ${CERT_FILE_NAME}
#     CERT_PATH=${DIR}/fabric-network/crypto-config/peerOrganizations/${DOMAIN}.example.com/users/Admin@${DOMAIN}.example.com/msp/signcerts/${CERT_FILE_NAME}
#     cp ${CERT_PATH} .

#     PRIVATE_KEY_PATH=${DIR}/fabric-network/crypto-config/peerOrganizations/${DOMAIN}.example.com/users/Admin@${DOMAIN}.example.com/msp/keystore
#     PRIVATE_KEY=$(ls ${PRIVATE_KEY_PATH}/*_sk)
#     rm -f *_sk
#     cp ${PRIVATE_KEY} .
#     PRIVATE_KEY=$(ls *_sk)

#     # remove card if exists
#     if docker exec ${COMPOSER_CONTAINER_NAME} composer card list -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} > /dev/null; then
#         docker exec ${COMPOSER_CONTAINER_NAME} composer card delete -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME}
#         rm -rf ./cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}
#     fi

#     # Create connection profile
#     docker exec ${COMPOSER_CONTAINER_NAME} composer card create -p ./connection.json -u ${FABRIC_NETWORK_PEERADMIN} -c "${CERT_FILE_NAME}" -k "${PRIVATE_KEY}" -r PeerAdmin -r ChannelAdmin -f ./cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}

#     # import PeerAdmin card to Composer
#     docker exec ${COMPOSER_CONTAINER_NAME} composer card import --file ./cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}

#     rm -rf ./connection.json ${CERT_FILE_NAME} ${PRIVATE_KEY}

#     echo "Hyperledger Composer PeerAdmin card has been imported"
#     # Show imported cards
#     docker exec ${COMPOSER_CONTAINER_NAME} composer card list
# }

# # Get network name
# function askNetworkName () {
#     read -p "Business network name: " COMPOSER_NETWORK_NAME
#     if [ ! -d "$COMPOSER_NETWORK_NAME" ]; then
#         echo "Business network not found! Enter Business network name which you defined during building the composer network."
#         askNetworkName
#     fi
# }

# function replaceVersionNr () {
#     # sed on MacOSX does not support -i flag with a null extension. We will use
#     # 't' for our back-up's extension and depete it at the end of the function
#     ARCH=`uname -s | grep Darwin`
#     if [ "$ARCH" == "Darwin" ]; then
#         OPTS="-it"
#     else
#         OPTS="-i"
#     fi

#     # change default version
#     sed $OPTS 's/"version": "0.0.'${1}'"/"version": "0.0.'${NETWORK_ARCHIVE_VERSION}'"/g' ${COMPOSER_NETWORK_NAME}/package.json
#     # If MacOSX, remove the temporary backup of the docker-compose file
#     if [ "$ARCH" == "Darwin" ]; then
#         rm -rf ${COMPOSER_NETWORK_NAME}/package.jsont
#     fi
# }

# # deploy
# function networkDeploy () {
#     askNetworkName

#     replaceVersionNr 1

#     # Generate a business network archive
#     docker exec ${COMPOSER_CONTAINER_NAME} composer archive create -t dir -n ${COMPOSER_NETWORK_NAME} -a network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

#     # Install the composer network
#     docker exec ${COMPOSER_CONTAINER_NAME} composer network install --card ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} --archiveFile network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

#     # remove card if exists
#     if docker exec ${COMPOSER_CONTAINER_NAME} composer card list -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} > /dev/null; then
#         docker exec ${COMPOSER_CONTAINER_NAME} composer card delete -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}
#         rm -rf ./cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card
#     fi

#     # network archive created from the previous command
#     NETWORK_ARCHIVE=./network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

#     # Deploy the business network, from COMPOSER_NETWORK_NAME directory
#     docker exec ${COMPOSER_CONTAINER_NAME} composer network start --card ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} --networkAdmin ${CA_USER_ENROLLMENT} --networkAdminEnrollSecret ${CA_ENROLLMENT_SECRET} --networkName ${COMPOSER_NETWORK_NAME} --networkVersion 0.0.${NETWORK_ARCHIVE_VERSION} --file ./cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card --loglevel ${FABRIC_LOGGING_LEVEL}

#     # Import the network administrator identity as a usable business network card
#     docker exec ${COMPOSER_CONTAINER_NAME} composer card import --file ./cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card

#     echo "Hyperledger Composer admin card has been imported"
#     # Show imported cards
#     docker exec ${COMPOSER_CONTAINER_NAME} composer card list

#     # Check if the business network has been deployed successfully
#     docker exec ${COMPOSER_CONTAINER_NAME} composer network ping --card ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}

# }

# # update
# function networkUpgrade () {
#     askNetworkName
#     replaceVersionNr ${NUMBER_OF_FILES}

#     # Generate a business network archive
#     docker exec ${COMPOSER_CONTAINER_NAME} composer archive create -t dir -n ${COMPOSER_NETWORK_NAME} -a network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

#     # network archive created from the previous command
#     NETWORK_ARCHIVE=./network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

#     # install the new business network
#     docker exec ${COMPOSER_CONTAINER_NAME} composer network install -a ${NETWORK_ARCHIVE} -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME}

#     # Upgrade to the new business network that was installed
#     docker exec ${COMPOSER_CONTAINER_NAME} composer network upgrade -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} -n ${COMPOSER_NETWORK_NAME} -V 0.0.${NETWORK_ARCHIVE_VERSION}
# }

# function askParticipantName() {
#     read -p "Participant username: " PARTICIPANT_EMAIL
#     if [ -z $PARTICIPANT_EMAIL ]; then
#         echo "Please enter Participant username"
#         askParticipantName
#     fi
# }

# # add new participant
# function addAdminParticipant() {

#    askNetworkName

#    askParticipantName

#    CURRENT_TIME=$(date)

#    read -p "New Participant first name: " PARTICIPANT_FIRST_NAME
#    if [ -z $PARTICIPANT_FIRST_NAME ]; then
#         echo "first name not set. standard first name will be set"
#         PARTICIPANT_FIRST_NAME="first name_${CURRENT_TIME}"
#     fi

#     read -p "New Participant last name: " PARTICIPANT_LAST_NAME
#     if [ -z $PARTICIPANT_LAST_NAME ]; then
#         echo "last name not set. standard last name will be set"
#         PARTICIPANT_LAST_NAME="last name_${CURRENT_TIME}"
#     fi

#     PARTICIPANT_JSON='{
#         "$class": "org.eyes.znueni.User",
#         "email": "'${PARTICIPANT_EMAIL}'",
#         "firstName": "'${PARTICIPANT_FIRST_NAME}'",
#         "lastName": "'${PARTICIPANT_LAST_NAME}'",
#         "balance": "0.00",
#         "isAdmin": "true",
#         "isActive": "true",
#         "profileImage": "no-image",
#         "gender": "M"
#     }'

#     # remove card if exists
#     if docker exec ${COMPOSER_CONTAINER_NAME} composer card list -c ${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME} > /dev/null; then
#         docker exec ${COMPOSER_CONTAINER_NAME} composer card delete -c ${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}
#         rm -rf ./cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card
#     fi

#     docker exec ${COMPOSER_CONTAINER_NAME} composer participant add -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} -d "${PARTICIPANT_JSON}"
#     docker exec ${COMPOSER_CONTAINER_NAME} composer identity issue -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} -f ./cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card -u ${PARTICIPANT_EMAIL} -a "resource:org.eyes.znueni.User#"${PARTICIPANT_EMAIL}""
#     docker exec ${COMPOSER_CONTAINER_NAME} composer card import --file ./cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card
#     docker exec ${COMPOSER_CONTAINER_NAME} composer card list
#     docker exec ${COMPOSER_CONTAINER_NAME} composer card export -f cards/${PARTICIPANT_EMAIL}_rest@${COMPOSER_NETWORK_NAME}.card -c ${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME} ; rm -f cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card
# }

# # crete Card for participant which already exists
# function createParticipantCard() {
#     askNetworkName
#     askParticipantName
#     docker exec ${COMPOSER_CONTAINER_NAME} composer identity issue -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} -f ./cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card -u ${PARTICIPANT_EMAIL} -a "resource:org.eyes.znueni.User#"${PARTICIPANT_EMAIL}""
#     docker exec ${COMPOSER_CONTAINER_NAME} composer card import --file ./cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card
#     docker exec ${COMPOSER_CONTAINER_NAME} composer card list
#     docker exec ${COMPOSER_CONTAINER_NAME} composer card export -f cards/${PARTICIPANT_EMAIL}_rest@${COMPOSER_NETWORK_NAME}.card -c ${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME} ; rm -f cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card
# }

# function upgradeComposer() {
#     # remove old container and image
#     docker stop ${COMPOSER_CONTAINER_NAME} || true && docker rm -f ${COMPOSER_CONTAINER_NAME} || true && docker rmi -f ${DOMAIN}/composer-cli || true

#     # recreate container
#     recreateComposer
# }

# # start the docker composer-cli container
# function start() {
#     docker start ${COMPOSER_CONTAINER_NAME}
# }

# # stop the docker composer-cli container
# function stop() {
#     docker stop ${COMPOSER_CONTAINER_NAME}
# }

NUMBER_OF_FILES=$(ls network-archives/ | wc -l)
COMPOSER_WORKING_DIR=/root/hyperledger/composer
CERT_FILE_NAME=Admin@${DOMAIN}.example.com-cert.pem
XCERT_FILE_NAME=Admin@${DOMAIN2}.example.com-cert.pem
EXTERNAL_NETWORK=byfh
DOCKER_STACK_NAME=ehr

# Parse commandline args
while getopts "h?m:e:s:" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    m)  MODE=$OPTARG
    ;;
    e)  EXTERNAL_NETWORK=$OPTARG
    ;;
    s)  DOCKER_STACK_NAME=$OPTARG
    ;;
  esac
done

# Determine whether building or deploying for announce
if [ "$MODE" == "build" ]; then
  EXPMODE="Building"
  elif [ "$MODE" == "deploy" ]; then
    EXPMODE="Deploying"
  elif [ "$MODE" == "upgrade" ]; then
    EXPMODE="Upgrading"
  elif [ "$MODE" == "start" ]; then
    EXPMODE="Starting composer-cli container"
  elif [ "$MODE" == "recreate" ]; then
    EXPMODE="Recreating composer-cli container"
  elif [ "$MODE" == "install" ]; then
    EXPMODE="Installling Composer Chaincode"
  elif [ "$MODE" == "addAdminParticipant" ]; then
    EXPMODE="Creating admin participant"
  elif [ "$MODE" == "createParticipantCard" ]; then
    EXPMODE="Creating participant card"
  elif [ "$MODE" == "upgradeComposer" ]; then
    EXPMODE="Upgrading Composer"
else
  printHelp
  exit 1
fi

# Announce what was requested
echo "${EXPMODE}"

# building or deploying the network
if [ "${MODE}" == "build" ]; then
  networkBuild
  elif [ "${MODE}" == "deploy" ]; then
    networkDeploy
  elif [ "${MODE}" == "upgrade" ]; then
    networkUpgrade
  elif [ "${MODE}" == "start" ]; then
    networkStart
  elif [ "${MODE}" == "install" ]; then
    networkInstall
  elif [ "${MODE}" == "recreate" ]; then
    recreateComposer
  elif [ "${MODE}" == "addAdminParticipant" ]; then
    addAdminParticipant
  elif [ "${MODE}" == "createParticipantCard" ]; then
    createParticipantCard
  elif [ "${MODE}" == "upgradeComposer" ]; then
    upgradeComposer
else
  printHelp
  exit 1
fi