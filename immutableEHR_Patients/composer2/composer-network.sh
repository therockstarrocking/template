#!/bin/bash

#
# Copyright Waleed El Sayed All Rights Reserved.
#

#
# This script builds, deploys or updates the composer network
#

# Grab the current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FABRIC_CRYPTO_CONFIG=../channel-artifacts/crypto-config

# set all variables in .env file as environmental variables
set -o allexport
source ${DIR}/fabric-network/.env
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
function connectionCredentials () {
    rm -f ${DIR}/.connection.json

    CA_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.exapmle.com/ca/ca.${DOMAIN}.exapmle.com-cert.pem)"
    ORDERER_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/ordererOrganizations/${DOMAIN}/orderers/orderer.${DOMAIN}/msp/tlscacerts/tlsca.${DOMAIN}-cert.pem)"
    PEER0_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.exapmle.com/peers/peer0.${DOMAIN}.exapmle.com/msp/tlscacerts/tlsca.${DOMAIN}.exapmle.com-cert.pem)"
    PEER1_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.exapmle.com/peers/peer1.${DOMAIN}.exapmle.com/msp/tlscacerts/tlsca.${DOMAIN}.exapmle.com-cert.pem)"

cat << EOF > ${DIR}/.connection.json
{
  "name": "fabric-network",
  "x-type": "hlfv1",
  "x-commitTimeout": 300,
  "version": "1.0.0",
  "client": {
    "organization": "Org1",
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
        "orderer.${DOMAIN}"
      ],
      "peers": {
        "peer0.${DOMAIN}.exapmle.com": {
          "endorsingPeer": true,
          "chaincodeQuery": true,
          "ledgerQuery": true,
          "eventSource": true
        },
        "peer1.${DOMAIN}.exapmle.com": {
          "endorsingPeer": true,
          "chaincodeQuery": true,
          "ledgerQuery": true,
          "eventSource": true
        }
      }
    }
  },
  "organizations": {
    "Org1": {
      "mspid": "Org1MSP",
      "peers": [
        "peer0.${DOMAIN}.exapmle.com",
        "peer1.${DOMAIN}.exapmle.com"
      ],
      "certificateAuthorities": [
        "ca.${DOMAIN}.exapmle.com"
      ]
    }
  },
  "orderers": {
    "orderer.${DOMAIN}": {
      "url": "grpcs://orderer.${DOMAIN}:7050",
      "grpcOptions": {
        "ssl-target-name-override": "orderer.${DOMAIN}",
        "grpc.keepalive_time_ms": 600000,
        "grpc.max_send_message_length": 15728640,
        "grpc.max_receive_message_length": 15728640
      },
      "tlsCACerts": {
        "pem": "${ORDERER_CERT}"
      }
    }
  },
  "peers": {
    "peer0.${DOMAIN}.exapmle.com": {
      "url": "grpcs://peer0.${DOMAIN}.exapmle.com:7051",
      "eventUrl": "grpcs://peer0.${DOMAIN}.exapmle.com:7053",
      "grpcOptions": {
        "ssl-target-name-override": "peer0.${DOMAIN}.exapmle.com"
      },
      "tlsCACerts": {
        "pem": "${PEER0_CERT}"
      }
    },
    "peer1.${DOMAIN}.exapmle.com": {
      "url": "grpcs://peer1.${DOMAIN}.exapmle.com:7051",
      "eventUrl": "grpcs://peer1.${DOMAIN}.exapmle.com:7053",
      "grpcOptions": {
        "ssl-target-name-override": "peer1.${DOMAIN}.exapmle.com"
      },
      "tlsCACerts": {
        "pem": "${PEER1_CERT}"
      }
    }
  },
  "certificateAuthorities": {
    "ca.${DOMAIN}.exapmle.com": {
      "url": "https://ca.${DOMAIN}.exapmle.com:7054",
      "caName": "ca.${DOMAIN}.exapmle.com",
      "tlsCACerts": {
        "pem": "${CA_CERT}"
      }
    }
  }
}
EOF

}

# create node container and install composer-cli on it
function buildComposer () {
    #docker stop ${COMPOSER_CONTAINER_NAME} || true && docker rm -f ${COMPOSER_CONTAINER_NAME} || true && docker rmi -f ${DOMAIN}/composer-cli || true

    cd ${DIR}/docker
    docker build -t ${DOMAIN}/composer-cli .
    cd ${DIR}

    rm -rf ${DIR}/.composer

    # docker run \
    #     -d \
    #     -it \
    #     -e TZ=${TIME_ZONE} \
    #     -w ${COMPOSER_WORKING_DIR} \
    #     -v ${DIR}:${COMPOSER_WORKING_DIR} \
    #     -v ${DIR}/.composer:/root/.composer \
    #     --name ${COMPOSER_CONTAINER_NAME} \
    #     --network ${FABRIC_DOCKER_NETWORK_NAME} \
    #     --restart=always \
    #     -p 9090:9090 \
    #     ${DOMAIN}/composer-cli
    docker stack deploy ${STACK_NAME} -c docker-composer.yaml
}

# recreate node container and install composer-cli on it
function recreateComposer () {
    #docker stop ${COMPOSER_CONTAINER_NAME} || true && docker rm -f ${COMPOSER_CONTAINER_NAME} || true

    # docker run \
    #     -d \
    #     -it \
    #     -e TZ=${TIME_ZONE} \
    #     -w ${COMPOSER_WORKING_DIR} \
    #     -v ${DIR}:${COMPOSER_WORKING_DIR} \
    #     -v ${DIR}/.composer:/root/.composer \
    #     --name ${COMPOSER_CONTAINER_NAME} \
    #     --network ${FABRIC_DOCKER_NETWORK_NAME} \
    #     --restart=always \
    #     -p 9090:9090 \
    #     ${DOMAIN}/composer-cli
}

# build
function networkBuild () {

    # create node container and install composer-cli on it
    buildComposer

    if [ -d "$FABRIC_CRYPTO_CONFIG" ]
        then
            rm -rf ./fabric-network/crypto-config
            ln -s ../${FABRIC_CRYPTO_CONFIG}/ fabric-network/
        else
            echo "Fabric crypto-config not found! Please run './fabric-network.sh -m build' in fabric directory"
            exit
    fi

    rm -f ./cards/*.card

    connectionCredentials

    rm -f ${CERT_FILE_NAME}
    CERT_PATH=${DIR}/fabric-network/crypto-config/peerOrganizations/${DOMAIN}.exapmle.com/users/Admin@${DOMAIN}.exapmle.com/msp/signcerts/${CERT_FILE_NAME}
    cp ${CERT_PATH} .

    PRIVATE_KEY_PATH=${DIR}/fabric-network/crypto-config/peerOrganizations/${DOMAIN}.exapmle.com/users/Admin@${DOMAIN}.exapmle.com/msp/keystore
    PRIVATE_KEY=$(ls ${PRIVATE_KEY_PATH}/*_sk)
    rm -f *_sk
    cp ${PRIVATE_KEY} .
    PRIVATE_KEY=$(ls *_sk)

    # remove card if exists
    if docker exec ${COMPOSER_CONTAINER_NAME} composer card list -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} > /dev/null; then
        docker exec ${COMPOSER_CONTAINER_NAME} composer card delete -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME}
        rm -rf ./cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}
    fi

    # Create connection profile
    docker exec ${COMPOSER_CONTAINER_NAME} composer card create -p .connection.json -u ${FABRIC_NETWORK_PEERADMIN} -c "${CERT_FILE_NAME}" -k "${PRIVATE_KEY}" -r PeerAdmin -r ChannelAdmin -f ./cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}

    # import PeerAdmin card to Composer
    docker exec ${COMPOSER_CONTAINER_NAME} composer card import --file ./cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}

    rm -rf .connection.json ${CERT_FILE_NAME} ${PRIVATE_KEY}

    echo "Hyperledger Composer PeerAdmin card has been imported"
    # Show imported cards
    docker exec ${COMPOSER_CONTAINER_NAME} composer card list
}

# Get network name
function askNetworkName () {
    read -p "Business network name: " COMPOSER_NETWORK_NAME
    if [ ! -d "$COMPOSER_NETWORK_NAME" ]; then
        echo "Business network not found! Enter Business network name which you defined during building the composer network."
        askNetworkName
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

# deploy
function networkDeploy () {
    askNetworkName

    replaceVersionNr 1

    # Generate a business network archive
    docker exec ${COMPOSER_CONTAINER_NAME} composer archive create -t dir -n ${COMPOSER_NETWORK_NAME} -a network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

    # Install the composer network
    docker exec ${COMPOSER_CONTAINER_NAME} composer network install --card ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} --archiveFile network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

    # remove card if exists
    if docker exec ${COMPOSER_CONTAINER_NAME} composer card list -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} > /dev/null; then
        docker exec ${COMPOSER_CONTAINER_NAME} composer card delete -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}
        rm -rf ./cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card
    fi

    # network archive created from the previous command
    NETWORK_ARCHIVE=./network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

    # Deploy the business network, from COMPOSER_NETWORK_NAME directory
    docker exec ${COMPOSER_CONTAINER_NAME} composer network start --card ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} --networkAdmin ${CA_USER_ENROLLMENT} --networkAdminEnrollSecret ${CA_ENROLLMENT_SECRET} --networkName ${COMPOSER_NETWORK_NAME} --networkVersion 0.0.${NETWORK_ARCHIVE_VERSION} --file ./cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card --loglevel ${FABRIC_LOGGING_LEVEL}

    # Import the network administrator identity as a usable business network card
    docker exec ${COMPOSER_CONTAINER_NAME} composer card import --file ./cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card

    echo "Hyperledger Composer admin card has been imported"
    # Show imported cards
    docker exec ${COMPOSER_CONTAINER_NAME} composer card list

    # Check if the business network has been deployed successfully
    docker exec ${COMPOSER_CONTAINER_NAME} composer network ping --card ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}

}

# update
function networkUpgrade () {
    askNetworkName
    replaceVersionNr ${NUMBER_OF_FILES}

    # Generate a business network archive
    docker exec ${COMPOSER_CONTAINER_NAME} composer archive create -t dir -n ${COMPOSER_NETWORK_NAME} -a network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

    # network archive created from the previous command
    NETWORK_ARCHIVE=./network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

    # install the new business network
    docker exec ${COMPOSER_CONTAINER_NAME} composer network install -a ${NETWORK_ARCHIVE} -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME}

    # Upgrade to the new business network that was installed
    docker exec ${COMPOSER_CONTAINER_NAME} composer network upgrade -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} -n ${COMPOSER_NETWORK_NAME} -V 0.0.${NETWORK_ARCHIVE_VERSION}
}

function askParticipantName() {
    read -p "Participant username: " PARTICIPANT_EMAIL
    if [ -z $PARTICIPANT_EMAIL ]; then
        echo "Please enter Participant username"
        askParticipantName
    fi
}

# add new participant
function addAdminParticipant() {

   askNetworkName

   askParticipantName

   CURRENT_TIME=$(date)

   read -p "New Participant first name: " PARTICIPANT_FIRST_NAME
   if [ -z $PARTICIPANT_FIRST_NAME ]; then
        echo "first name not set. standard first name will be set"
        PARTICIPANT_FIRST_NAME="first name_${CURRENT_TIME}"
    fi

    read -p "New Participant last name: " PARTICIPANT_LAST_NAME
    if [ -z $PARTICIPANT_LAST_NAME ]; then
        echo "last name not set. standard last name will be set"
        PARTICIPANT_LAST_NAME="last name_${CURRENT_TIME}"
    fi

    PARTICIPANT_JSON='{
        "$class": "org.eyes.znueni.User",
        "email": "'${PARTICIPANT_EMAIL}'",
        "firstName": "'${PARTICIPANT_FIRST_NAME}'",
        "lastName": "'${PARTICIPANT_LAST_NAME}'",
        "balance": "0.00",
        "isAdmin": "true",
        "isActive": "true",
        "profileImage": "no-image",
        "gender": "M"
    }'

    # remove card if exists
    if docker exec ${COMPOSER_CONTAINER_NAME} composer card list -c ${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME} > /dev/null; then
        docker exec ${COMPOSER_CONTAINER_NAME} composer card delete -c ${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}
        rm -rf ./cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card
    fi

    docker exec ${COMPOSER_CONTAINER_NAME} composer participant add -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} -d "${PARTICIPANT_JSON}"
    docker exec ${COMPOSER_CONTAINER_NAME} composer identity issue -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} -f ./cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card -u ${PARTICIPANT_EMAIL} -a "resource:org.eyes.znueni.User#"${PARTICIPANT_EMAIL}""
    docker exec ${COMPOSER_CONTAINER_NAME} composer card import --file ./cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card
    docker exec ${COMPOSER_CONTAINER_NAME} composer card list
    docker exec ${COMPOSER_CONTAINER_NAME} composer card export -f cards/${PARTICIPANT_EMAIL}_rest@${COMPOSER_NETWORK_NAME}.card -c ${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME} ; rm -f cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card
}

# crete Card for participant which already exists
function createParticipantCard() {
    askNetworkName
    askParticipantName
    docker exec ${COMPOSER_CONTAINER_NAME} composer identity issue -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} -f ./cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card -u ${PARTICIPANT_EMAIL} -a "resource:org.eyes.znueni.User#"${PARTICIPANT_EMAIL}""
    docker exec ${COMPOSER_CONTAINER_NAME} composer card import --file ./cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card
    docker exec ${COMPOSER_CONTAINER_NAME} composer card list
    docker exec ${COMPOSER_CONTAINER_NAME} composer card export -f cards/${PARTICIPANT_EMAIL}_rest@${COMPOSER_NETWORK_NAME}.card -c ${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME} ; rm -f cards/${PARTICIPANT_EMAIL}@${COMPOSER_NETWORK_NAME}.card
}

function upgradeComposer() {
    # remove old container and image
    docker stop ${COMPOSER_CONTAINER_NAME} || true && docker rm -f ${COMPOSER_CONTAINER_NAME} || true && docker rmi -f ${DOMAIN}/composer-cli || true

    # recreate container
    recreateComposer
}

# start the docker composer-cli container
function start() {
    docker start ${COMPOSER_CONTAINER_NAME}
}

# stop the docker composer-cli container
function stop() {
    docker stop ${COMPOSER_CONTAINER_NAME}
}

NUMBER_OF_FILES=$(ls network-archives/ | wc -l)
NETWORK_ARCHIVE_VERSION=$(( ${NUMBER_OF_FILES}+1 ))
COMPOSER_WORKING_DIR=/root/hyperledger/composer
CERT_FILE_NAME=Admin@${DOMAIN}.exapmle.com-cert.pem

# Parse commandline args
while getopts "h?m:" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    m)  MODE=$OPTARG
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
  elif [ "$MODE" == "stop" ]; then
    EXPMODE="Stopping composer-cli container"
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
    start
  elif [ "${MODE}" == "stop" ]; then
    stop
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