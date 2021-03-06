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
CURR_PATH=$PWD

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  ./composer-network.sh -m build|install|deploy|createadmin|upgrade"
  echo "  ./composer-network.sh -h|--help (print this message)"
  echo "    -m <mode> - one of 'build', 'deploy'"
  echo "      - 'build' - build the network"
  echo "      - 'deploy' - deploy the network"
  echo "      - 'install' - install chaincode "
  echo "      - 'deploy' - deploy the network"
  echo "      - 'upgrade' - upgrade the network"
  echo "   -c <Composer network name>"
  echo "   -v <bna version >"
}

# Connection credentials
function verify () {
  if [ $1 -ne 0 ];  then
    echo "....$2..."
    exit 1
  fi
}
function connectionCredentials () {
    rm -f ${CURR_PATH}/connection.json
    DOMAI=$1
    DOMAI2=$2
    CA2_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAI2}.example.com/peers/peer0.${DOMAI2}.example.com/tls/ca.crt)"
    CA_CERT="$(awk '{printf "%s\\n", $0}' ./ca.crt)"
    verify $? "failed ... try again"
    ORDERER_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt)"
cat << EOF > ${DIR}/connection.json
{
  "name": "${COMPOSER_FABRIC_NETWORK_NAME}",
  "x-type": "hlfv1",
  "x-commitTimeout": 300,
  "version": "1.0.0",
  "client": {
    "organization": "${DOMAI}",
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
        "orderer.example.com"
      ],
      "peers": {
        "peer0.${DOMAI}.example.com": {
          "endorsingPeer": true,
          "chaincodeQuery": true,
          "eventSource": true
        },
        "peer1.${DOMAI}.example.com": {
          "endorsingPeer": true,
          "chaincodeQuery": true,
          "eventSource": true
        },
        "peer0.${DOMAI2}.example.com": {
          "endorsingPeer": true,
          "chaincodeQuery": true,
          "eventSource": true
        }
      }
    }
  },
  "organizations": {
    "${DOMAI}": {
      "mspid": "${DOMAI}MSP",
      "peers": [
        "peer0.${DOMAI}.example.com",
        "peer1.${DOMAI}.example.com"
      ],
      "certificateAuthorities": [
        "ca_peer${DOMAI}"
      ]
    },
    "${DOMAI2}": {
      "mspid": "${DOMAI2}MSP",
      "peers": [
        "peer0.${DOMAI2}.example.com"
      ],
      "certificateAuthorities": [
        "ca_peer${DOMAI2}"
      ]
    }
  },
  "orderers": {
    "orderer.example.com": {
      "url": "grpcs://localhost:7050",
      "grpcsOptions": {
        "ssl-target-name-override": "orderer.example.com"
      },
      "tlsCACerts": {
        "pem": "${ORDERER_CERT}"
      }
    }
  },
  "peers": {
    "peer0.${DOMAI}.example.com": {
      "url": "grpcs://localhost:7051",
      "eventUrl": "grpcs://localhost:7053",
      "grpcOptions": {
        "ssl-target-name-override": "peer0.${DOMAI}.example.com"
      },
      "tlsCACerts": {
        "pem": "${CA_CERT}"
      }
    },
    "peer1.${DOMAI}.example.com": {
      "url": "grpcs://localhost:8051",
      "eventUrl": "grpcs://localhost:8053",
      "grpcOptions": {
        "ssl-target-name-override": "peer1.${DOMAI}.example.com"
      },
      "tlsCACerts": {
        "pem": "${CA_CERT}"
      }
    },
    "peer0.${DOMAI2}.example.com": {
      "url": "grpcs://localhost:9051",
      "eventUrl": "grpcs://localhost:9053",
      "grpcOptions": {
        "ssl-target-name-override": "peer0.${DOMAI2}.example.com"
      },
      "tlsCACerts": {
        "pem": "${CA2_CERT}"
      }
    }
  },
  "certificateAuthorities": {
    "ca_peer${DOMAI}": {
      "url": "https://localhost:7054",
      "caName": "ca-${DOMAI}",
      "httpOptions": {
        "verify": false
      }
    },
    "ca_peer${DOMAI2}": {
      "url": "https://localhost:8054",
      "caName": "ca-${DOMAI2}",
      "httpOptions": {
        "verify": false
      }
    }
  }
}
EOF

}

# Get network name
function askNetworkName () {
    read -p "Business network name: " COMPOSER_NETWORK_NAME
    #read -p "Archive version: " NETWORK_ARCHIVE_VERSION
    # if [ ! -d "$COMPOSER_NETWORK_NAME" ]; then
    #     echo "Business network not found! Enter Business network name which you defined during building the composer network."
    #     askNetworkName
    # fi
}
function askVersion () {
  read -p "Archive version: " NETWORK_ARCHIVE_VERSION
}

CERT_FILE_NAME=Admin@${DOMAIN}.example.com-cert.pem
# build
function networkBuild () {

    # create node container and install composer-cli on it
    #buildComposer
    if [ !COMPOSER_NETWORK_NAME ]; then
      askNetworkName
    fi
  echo $COMPOSER_NETWORK_NAME
    if [ -d "$FABRIC_CRYPTO_CONFIG" ]
        then
            rm -rf ./fabric-network/crypto-config
            ln -s ${FABRIC_CRYPTO_CONFIG}/ fabric-network/
        else
            echo "Fabric crypto-config not found! Please run './fabric-network-temp.sh -m build' in fabric directory"
            exit
    fi

    rm -f ./cards/*.card

    connectionCredentials "Patients" "XyzHospitals"

    rm -f ${CERT_FILE_NAME}
    CERT_PATH=${DIR}/${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.example.com/users/Admin@${DOMAIN}.example.com/msp/signcerts/${CERT_FILE_NAME}
    verify $? "FAILED...TRY AGAIN "
    cp ${CERT_PATH} .

    PRIVATE_KEY_PATH=${DIR}/${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.example.com/users/Admin@${DOMAIN}.example.com/msp/keystore
    PRIVATE_KEY=$(ls ${PRIVATE_KEY_PATH}/*_sk)
    rm -f *_sk
    cp ${PRIVATE_KEY} .
    PRIVATE_KEY=$(ls *_sk)

    # remove card if exists
    if composer card list -c PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN} > /dev/null; then
        composer card delete -c PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN}
        composer card delete -c bob@${COMPOSER_NETWORK_NAME}
        rm -rf ./cards/
        rm -rf ~/.composer/
    fi

    # Create connection profile
  #  composer card create -p connection.json -u ${FABRIC_NETWORK_PEERADMIN} -c "${CERT_FILE_NAME}" -k "${PRIVATE_KEY}" -r PeerAdmin -r ChannelAdmin -f ./cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}

  #   # import PeerAdmin card to Composer
  #   composer card import --file ./cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}

  #   #rm -rf .connection.json ${CERT_FILE_NAME} ${PRIVATE_KEY}

    echo "Hyperledger Composer PeerAdmin card has been imported"
    # Show imported cards
    composer card list
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
    if [ !COMPOSER_NETWORK_NAME ]; then
      askNetworkName
    fi
    if [ !NETWORK_ARCHIVE_VERSION ]; then
      askVersion
    fi

    #replaceVersionNr 1
    composer card create -p ./connection.json -u PeerAdmin -c ./Admin@${DOMAIN}.example.com-cert.pem -k ./*_sk -r PeerAdmin -r ChannelAdmin -f ./cards/PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN}.card

    composer card import -f ./cards/PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN}.card --card PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN}
    networkInstall
    # Generate a business network archive
    #docker exec ${COMPOSER_CONTAINER_NAME} 
    #composer archive create -t dir -n ${COMPOSER_NETWORK_NAME} -a network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

    # Install the composer network
    #composer network install --card ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} --archiveFile network-archives/${COMPOSER_NETWORK_NAME}@0.0.1.bna
    
    # # remove card if exists
    # if composer card list -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} > /dev/null; then
    #     composer card delete -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}
    #     rm -rf ./cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card
    # fi

    # # network archive created from the previous command
    # NETWORK_ARCHIVE=./network-archives/${COMPOSER_NETWORK_NAME}@0.0.1.bna

    # # Deploy the business network, from COMPOSER_NETWORK_NAME directory
    # composer network start --card ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} --networkAdmin ${CA_USER_ENROLLMENT} --networkAdminEnrollSecret adminpw --networkName ${COMPOSER_NETWORK_NAME} --networkVersion ${NETWORK_ARCHIVE_VERSION} --file ./cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card --loglevel ${FABRIC_LOGGING_LEVEL}
    # composer network start --card PeerAdmin@immutehr --networkAdmin admin --networkAdminEnrollSecret adminpw --networkName composer-network --networkVersion 0.0.1 --file ./cards/PeerAdmin@immutehr.card

    # # Import the network administrator identity as a usable business network card
    # composer card import --file ./cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card

    echo "Hyperledger Composer admin card has been imported"
    # Show imported cards
    composer card list

    # Check if the business network has been deployed successfully
    #composer network ping --card ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}
    # composer network start -c PeerAdmin@samplenet-Patients -n samplenet -V 0.0.1 -A bob -C ./cards/bob/admin-pub.pem -A bob -C ./cards/bob/admin-pub.pem

}
function networkInstall () {
  echo $COMPOSER_NETWORK_NAME
  echo $NETWORK_ARCHIVE_VERSION
  if [ !COMPOSER_NETWORK_NAME ]; then
    askNetworkName
  fi
  if [ !NETWORK_ARCHIVE_VERSION ]; then
    askVersion
  fi
  composer network install --card PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN} --archiveFile ./network-archives/${COMPOSER_NETWORK_NAME}@${NETWORK_ARCHIVE_VERSION}.bna
  cd ./cards/
  if [ ! -d "bob" ]; then
    cd ../
    composer identity request -c PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN} -u admin -s adminpw -d ./cards/bob
  fi
  

}

function networkStart () {
  if [ !COMPOSER_NETWORK_NAME ]; then
    askNetworkName
  fi
  if [ !NETWORK_ARCHIVE_VERSION ]; then
    askVersion
  fi
  composer network start -c PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN} -n ${COMPOSER_NETWORK_NAME} -V ${NETWORK_ARCHIVE_VERSION} -A bob -C ./cards/bob/admin-pub.pem -A alice -C ./cards/alice/admin-pub.pem
  verify $? "failed to start the network"
}
function networAdminsCreate () {
  if [ !COMPOSER_NETWORK_NAME ]; then
    askNetworkName  
  fi
  composer card create -p ./connection.json -u bob -n ${COMPOSER_NETWORK_NAME} -c bob/admin-pub.pem -k bob/admin-priv.pem -f ./cards/bob@${COMPOSER_NETWORK_NAME}.card
  composer card import -f ./cards/bob@${COMPOSER_NETWORK_NAME}.card
  composer network ping -c bob@${COMPOSER_NETWORK_NAME}
}

function networkUpgrade(){
   if [ !COMPOSER_NETWORK_NAME ]; then
    askNetworkName
  fi
  if [ !NETWORK_ARCHIVE_VERSION ]; then
    askVersion
  fi
  networkInstall
  composer network upgrade -c PeerAdmin@${COMPOSER_NETWORK_NAME}-${DOMAIN} -n ${COMPOSER_NETWORK_NAME} -V ${NETWORK_ARCHIVE_VERSION} -A bob -C ./cards/bob/admin-pub.pem -A alice -C ./cards/alice/admin-pub.pem

}


# Ask user for confirmation to proceed
function askProceed () {
  read -p "Continue (y/n)? " ans
  case "$ans" in
    y|Y )
      echo "proceeding ..."
    ;;
    n|N )
      echo "exiting..."
      exit 1
    ;;
    * )
      echo "invalid response"
      askProceed
    ;;
  esac
}


while getopts "h?m:c:v" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    m)  MODE=$OPTARG
    ;;
    c)  COMPOSER_NETWORK_NAME=$OPTARG
    ;;
    v)  NETWORK_ARCHIVE_VERSION=$OPTARG
  esac
done

# Determine whether starting, stopping or generating for announce
if [ "$MODE" == "build" ]; then
  EXPMODE="Building composer materials "
  elif [ "$MODE" == "install" ]; then
  EXPMODE="installing composer chaincode"
  elif [ "$MODE" == "deploy" ]; then
  EXPMODE="Create peerAdmin card and installing composer chaincode"
  elif [ "$MODE" == "start" ]; then
  EXPMODE="starting composer chaincode"
  elif [ "$MODE" == "createadmin" ]; then
  EXPMODE="Generating Admin participants"
  elif [ "$MODE" == "upgrade" ]; then
  EXPMODE="Upgrading chaincode"
else
  printHelp
  exit 1
fi

# Announce what was requested
#echo "${EXPMODE} on channel '${CHANNEL_NAME}' and CLI timeout of '${CLI_TIMEOUT}' in docker swarm mode , external network '${EXTERNAL_NETWORK}' and stack name '${DOCKER_STACK_NAME}'"

# ask for confirmation to proceed
askProceed

#Create the network using docker compose
if [ "${MODE}" == "build" ]; then
  networkBuild
  elif [ "${MODE}" == "deploy" ]; then ## Clear the network
  networkDeploy
  elif [ "${MODE}" == "install" ]; then ## Clear the network
  networkInstall
  elif [ "${MODE}" == "start" ]; then ## Clear the network
  networkStart
  elif [ "${MODE}" == "createadmin" ]; then ## Generate Artifacts
  networAdminsCreate
  elif [ "${MODE}" == "upgrade" ]; then ## Generate Artifacts
  networkUpgrade
else
  printHelp
  exit 1
fi


