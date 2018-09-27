#!/bin/bash

#
# Copyright Waleed El Sayed All Rights Reserved.
#
# Adaption from: https://github.com/hyperledger/fabric-samples/blob/release/first-network/byfn.sh
#

# This script will orchestrate end-to-end execution of the Hyperledger Fabric network.
#
# The end-to-end verification provisions a Fabric network consisting of
# on organization with maintaining two peers, and a “kafka” ordering service.
#
# This verification makes use of two fundamental tools, which are necessary to
# create a functioning transactional network with digital signature validation
# and access control:
#
# * cryptogen - generates the x509 certificates used to identify and
#   authenticate the various components in the network.
# * configtxgen - generates the requisite configuration artifacts for orderer
#   bootstrap and channel creation.
#
# Each tool consumes a configuration yaml file, within which we specify the topology
# of our network (cryptogen) and the location of our certificates for various
# configuration operations (configtxgen).  Once the tools have been successfully run,
# we are able to launch our network.  More detail on the tools and the structure of
# the network will be provided later in this document.  For now, let's get going...

# set all variables in .env file as environmental variables
set -o allexport
source .env
set +o allexport

# prepending $PWD/../../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
export PATH=${PWD}/${FABRIC_BINARIES_DIRECTORY}/bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}/../channel-artifacts
I_PATH=$PWD

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  ./fabric-network.sh -m build|entirebuild|down|generate|addorg|upgradechaincode [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>]"
  echo "  ./fabric-network.sh -h|--help (print this message)"
  echo "    -m <mode> - one of 'build', 'start', 'stop', 'down', 'recreate' or 'generate'"
  echo "      - 'build' - build the network with already existing certificates"
  echo "      - 'entirebuild' - build the network: generate required certificates and genesis block & create all containers needed for the network"
  echo "      - 'down' - remove the network containers"
  echo "      - 'generate' - generate required certificates and genesis block"
  echo "      - 'recreate' - recreate containers"
  echo "      - 'start' - start the containers"
  echo "      - 'stop' - stop the containers"
  echo "      - 'addorg' - adding new organisation into the network"
  echo "      - 'upgradechaincode' - upgrading chaincode to the new version"
  echo "    -c <channel name> - channel name to use (defaults to \"$CHANNEL_NAME\")"
  echo "    -t <timeout> - CLI timeout duration in microseconds (defaults to 10000)"
  echo "    -d <delay> - delay duration in seconds (defaults to 3)"
  echo "    -f <docker-compose-file> - specify which docker-compose file use (defaults to docker-compose.yaml)"
  echo
  echo "Typically for the first time, one would first generate the required certificates and "
  echo "genesis block, then build the network.:"
  echo
  echo "	./fabric-network.sh -m entirebuild"

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

# Obtain CONTAINER_IDS and remove them
function clearContainers () {
  CONTAINER_IDS=$(docker ps -a | grep "dev\|hyperledger/fabric-\|test-vp\|peer[0-9]-" | awk '{print $1}')
  if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
    echo "---- No containers available for deletion ----"
  else
    docker rm -f $CONTAINER_IDS
  fi
}

# Delete any images that were generated as a part of this setup
# specifically the following images are often left behind:
function removeUnwantedImages() {
  DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
  if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
    echo "---- No images available for deletion ----"
  else
    docker rmi -f $DOCKER_IMAGE_IDS
  fi
  docker volume rm $(docker volume ls|awk '{print $2}')
  if [ $? -ne 0 ]; then
      echo $?
      #exit 1
  fi
}

# Remove the Docker swarm configuration
function swarmRemove() {
    docker stack rm ${DOCKER_STACK_NAME} 2>&1
    if [ $? -ne 0 ]; then
        echo $?
        #exit 1
    fi
    docker network rm ${EXTERNAL_NETWORK} 2>&1
    if [ "$?" == "${EXTERNAL_NETWORK}" ]; then
        echo $?
        #exit 1
    fi
    SWARM_MODE_DEL=$(docker info | grep Swarm | awk '{print $2}')
    if [ "${SWARM_MODE_DEL}" == "active" ]; then
      docker swarm leave --force
      if [ $? -ne 0 ]; then
          echo $?
          #exit 1
      fi
    fi
}

# Create the Docker swarm to deploy stack file 
function swarmCreate() {
    SWARM_MODE=$(docker info | grep Swarm | awk '{print $2}')
    echo "SWARM_MODE = ${SWARM_MODE}"
    if [ "${SWARM_MODE}" != "active" ]; then
        echo " ---------- Creating Docker Swarm  ----------"
        docker swarm init 2>&1
        if [ $? -ne 0 ]; then
            echo $?
            exit 1
        fi
        echo " ---------- Creating Token to join  other ORGs as Manager ----------"
        docker swarm join-token manager | awk 'NR==3 {print}' > token.txt
        echo "TOKEN TO join swarm as manager "
        cat token.txt
        echo
    fi
    sleep 1
    DOC_NET=$(docker network ls|grep ${EXTERNAL_NETWORK}|awk '{print $2}')
    if [ "${DOC_NET}" != "${EXTERNAL_NETWORK}" ]; then
      echo " ---------- Creating External Network ----------"
      docker network create --attachable ${EXTERNAL_NETWORK} --driver overlay  2>&1
      if [ $? -ne 0 ]; then
          echo $?
       #exit 1
      fi
    fi
    sleep 1
}

# Generates Org certs using cryptogen tool
function generateCerts (){
  echo "genCerts"
  echo $PWD
  which cryptogen
  if [ "$?" -ne 0 ]; then
    echo "cryptogen tool not found. exiting"
    exit 1
  fi
  echo
  echo "##########################################################"
  echo "##### Generate certificates using cryptogen tool #########"
  echo "##########################################################"
  if [ -d "channel-artifacts" ]; then
    rm -Rf channel-artifacts
  fi
  cd ../
  mkdir channel-artifacts
  cd ./channel-artifacts/
  if [ -d "crypto-config" ]; then
    rm -Rf crypto-config
  fi

  # sed on MacOSX does not support -i flag with a null extension. We will use
  # 't' for our back-up's extension and depete it at the end of the function
  ARCH=`uname -s | grep Darwin`
  if [ "$ARCH" == "Darwin" ]; then
    OPTS="-it"
  else
    OPTS="-i"
  fi

  CRYPTO_CONFIG_FILE="crypto-config.yaml"
  # Copy the template to the file that will be modified to add the domain name
  echo $ORDERER_TYPE
  if [ "$ORDERER_TYPE" == "kafka" ];then
    cp ../template-files/crypto-config-kafka-template.yaml crypto-config.yaml
    else
    cp ../template-files/crypto-config-template.yaml crypto-config.yaml
  fi

  # The next steps will replace the template's contents with the
  # actual values of the domain name.
  sed $OPTS "s/DOMAIN/${DOMAIN}/g" "${CRYPTO_CONFIG_FILE}"
  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm "${CRYPTO_CONFIG_FILE}t"
  fi

  cryptogen generate --config=./${CRYPTO_CONFIG_FILE}
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate certificates..."
    exit 1
  fi
  echo
}


# Using docker-compose.yaml, replace constants with private key file names
# generated by the cryptogen tool and output a docker-compose-ca-base.yaml specific to this
# configuration
function replacePrivateKey () {
  # sed on MacOSX does not support -i flag with a null extension. We will use
  # 't' for our back-up's extension and depete it at the end of the function
  ARCH=`uname -s | grep Darwin`
  if [ "$ARCH" == "Darwin" ]; then
    OPTS="-it"
  else
    OPTS="-i"
  fi
  if [ "$DB" == "level" ]; then
    echo "Level DB"
    DOCKERTEMPLATE=docker-compose.yaml
  else
    if [ "$ORDERER_TYPE" == "kafka" ];then
      echo "KAFKA"
      DOCKERTEMPLATE=docker-compose-kafka-template.yaml
      else
        echo "couchDb"
        DOCKERTEMPLATE=docker-compose-couchdb-template.yaml
    fi
  fi
  COMPOSE_CA_FILE=docker-compose.yaml
  # Copy the template to the file that will be modified to add the private key
  cp ../template-files/$DOCKERTEMPLATE  "$COMPOSE_CA_FILE"

  # The next steps will replace the template's contents with the
  # actual values of the private key file names for the two CAs.
  CURRENT_DIR=$PWD
  cd ./crypto-config/peerOrganizations/$DOMAIN.example.com/ca/
  PRIV_KEY=$(ls *_sk)
  cd "$CURRENT_DIR"
  sed $OPTS "s/CA_PRIVATE_KEY/${PRIV_KEY}/g" "$COMPOSE_CA_FILE"
  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm "$COMPOSE_CA_FILE"
  fi
}

# Generate orderer genesis block and channel configuration transaction
function generateChannelArtifacts() {
    
  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  echo "Creating new Configuratio files"
  echo $PWD
  if [ -f "channel.tx" ]; then
    rm channel.tx genesis.block ${DOMAIN}MSPanchors.tx
  fi

  # sed on MacOSX does not support -i flag with a null extension. We will use
  # 't' for our back-up's extension and depete it at the end of the function
  ARCH=`uname -s | grep Darwin`
  if [ "$ARCH" == "Darwin" ]; then
    OPTS="-it"
  else
    OPTS="-i"
  fi

  CONFIGTX_FILE="configtx.yaml"
  # Copy the template to the file that will be modified to add the domain name
  echo $ORDERER_TYPE
  if [ "$ORDERER_TYPE" == "kafka" ];then
    cp ../template-files/configtx-kafka-template.yaml configtx.yaml
    else
    cp ../template-files/configtx-template.yaml configtx.yaml
  fi

  # The next steps will replace the template's contents with the
  # actual values of the domain name.
  sed $OPTS "s/DOMAIN/${DOMAIN}/g" "${CONFIGTX_FILE}"

  echo "##########################################################"
  echo "#########  Generating Orderer Genesis block ##############"
  echo "##########################################################"
  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
   configtxgen -profile ImmutableEhrOrdererGenesis -outputBlock ./$GENESIS_FILE_NAME
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate orderer genesis block..."
    exit 1
  fi
  echo
  echo "#########################################################################"
  echo "### Generating channel configuration transaction '$CHANNEL_FILE_NAME' ###"
  echo "#########################################################################"
   configtxgen -profile ImmutableEhrChannel -outputCreateChannelTx ./$CHANNEL_FILE_NAME -channelID $CHANNEL_NAME
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate channel configuration transaction..."
    exit 1
  fi

   configtxgen -profile ImmutableEhrChannel -outputAnchorPeersUpdate ./${DOMAIN}MSPanchors.tx -channelID $CHANNEL_NAME -asOrg ${DOMAIN}MSP
  if [ $? -ne 0 ]; then
    echo "Failed to generate Anchor update configuration transaction..."
    exit 1
  fi
  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm "${CONFIGTX_FILE}t"
  fi
}

#Generate network from scratch
function entireNetworkBuild() {
  echo $PWD
  networkDown
  networkBuild
}

# Generate the needed certificates, the genesis block and start the network.
function networkBuild () {
  # generate artifacts if they don't exist
  cd $I_PATH
  if [ ! -d "../channel-artifacts" ]; then
    generateCerts
    replacePrivateKey
    generateChannelArtifacts
  fi
  cd $I_PATH/../channel-artifacts
  FABRIC_LOGGING_LEVEL=INFO
  FABRIC_CA_ENABLE_DEBUG=
  sleep 1
  if [ "$DB" == "level" ]; then
    echo "Level DB"
    COMPOSE_FILE_TEMPLATE=../template-files/docker-compose.yaml
  else
    if [ "$ORDERER_TYPE" == "kafka" ];then
      echo "KAFKA"
      COMPOSE_FILE_TEMPLATE=../template-files/docker-compose-kafka-template.yaml
      else
        echo "KAFKA"
       COMPOSE_FILE_TEMPLATE=../template-files/docker-compose-couchdb-template.yaml
    fi
  fi
  CLI_COMPOSE_FILE=./docker-compose.yaml
  #cp "$CLI_COMPOSE_FILE_TEMPLATE" "$CLI_COMPOSE_FILE"

  # sed on MacOSX does not support -i flag with a null extension. We will use
  # 't' for our back-up's extension and depete it at the end of the function
  ARCH=`uname -s | grep Darwin`
  if [ "$ARCH" == "Darwin" ]; then
    OPTS="-it"
  else
    OPTS="-i"
  fi

  # add network name
  sed $OPTS "s/EXTERNAL_NETWORK/${EXTERNAL_NETWORK}/g" "$CLI_COMPOSE_FILE"
  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm "${CLI_COMPOSE_FILE}t"
  fi

  # replace volume names
  sed $OPTS "s/DOMAIN/${DOMAIN}/g" "$CLI_COMPOSE_FILE"
  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm "${CLI_COMPOSE_FILE}t"
  fi
  # remove ledger data
  #rm -rf ./ledger
  swarmCreate
  sleep 1
  CHANNEL_NAME=$CHANNEL_NAME TIMEOUT=$CLI_TIMEOUT DELAY=$CLI_DELAY 
  docker stack deploy ${DOCKER_STACK_NAME} -c $CLI_COMPOSE_FILE 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start network"
    CLI_CONTAINER=$(docker ps |grep tools|awk '{print $1}')
    docker logs -f ${CLI_CONTAINER}
    exit 1
  fi
  sleep 90
  CLI_CONTAINER=$(docker ps |grep tools|awk '{print $1}')
  docker exec ${CLI_CONTAINER} ./scripts/networkscripts/channelcreation.sh $CHANNEL_NAME $CLI_DELAY $CLI_TIMEOUT $DOMAIN 1.0 $ORDERER_TYPE
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! failed"
    exit 1
  fi
}


# Tear down running network
function networkDown () {
    swarmRemove
    #Cleanup the chaincode containers
    clearContainers
    #Cleanup images
    removeUnwantedImages

    # remove orderer block and other channel configuration transactions and certs
    rm -rf $I_PATH/../channel-artifacts
    # remove ledger data
    #rm -rf $I_PATH/../ledger
}
function verify () {
  if [ $1 -ne 0 ]; then
    echo $2
    exit 1
  fi
}
function readStack () {
  read -p "Docker Stack Name : " DOCKER_STACK_NAME
  if [ "$DOCKER_STACK_NAME" == "" ]; then
    readStack
  fi
}
function readNewOrgName () {
  read -p "New Organisatoin Name : " NEW_ORG_NAME
  if [ "$NEW_ORG_NAME" == "" ]; then
    readNewOrgName
  fi
}
function readChaincodeName () {
  read -p " Chaincode Name : " CHAINCODE_NAME
  if [ "$CHAINCODE_NAME" == "" ]; then
    readChaincodeName
  fi
}
function readChaincodeName () {
  read -p " Chaincode Version : " CHAINCODE_VERSION
  if [ "$CHAINCODE_VERSION" == "" ]; then
    readChaincodeName
  fi
}
function verifyConfigFile(){
  if [ ! -f $NEW_ORG_NAME.json ]; then 
    echo "No configuration file found for ${NEW_ORG_NAME}..."
    echo "Procceding to get the configuration file"
    askProceed
    read -p "${NEW_ORG_NAME} ssh address :" SSH_ADDRESS 
    scp -r ../channel-artifacts/crypto-config/ordererOrganizations/ ${SSH_ADDRESS}:./immutableEhr_${NEW_ORG_NAME}/channel-artifacts/crypto-config/
    scp ${SSH_ADDRESS}:./immutableEhr_${NEW_ORG_NAME}/channel-artifacts/${NEW_ORG_NAME}.json ../channel-artifacts/
    #exit 1
    if [ ! -f $NEW_ORG_NAME.json ]; then 
      verifyConfigFile
    fi
  fi
}
function addorg () {
    cd $I_PATH
    echo $DOCKER_STACK_NAME
    if [ "$DOCKER_STACK_NAME" == "" ]; then
      echo "Docker stack name is required"
      readStack
    fi
    if [ "$NEW_ORG_NAME" = "" ]; then
      echo "New organisation name is required"
      readNewOrgName
    fi
    cd ../channel-artifacts/
    verifyConfigFile
    cd $I_PATH
    CLI_CONTAINER=$(docker ps |grep ${DOCKER_STACK_NAME}_cli|awk '{print $1}')
    if [ "$CLI_CONTAINER" == "" ]; then
      echo "Failed to get the container .. try giving correct stack name"
      exit 1
    fi
    echo $CLI_CONTAINER
    echo " Orderer from fsh: $ORDERER_TYPE"
    docker exec ${CLI_CONTAINER} ./scripts/networkscripts/addneworg.sh $NEW_ORG_NAME $CHANNEL_NAME $ORDERER_TYPE
}

function upgradechaincode () {
    cd $I_PATH
    echo $DOCKER_STACK_NAME
    echo $NEW_ORG_NAME
    echo $CHAINCODE_NAME
    echo $CHAINCODE_VERSION
    if [ "$DOCKER_STACK_NAME" == "" ]; then
      echo "Docker stack name is required"
      readStack
    fi
    if [ "$NEW_ORG_NAME" == "" ]; then
      echo "New organisation name is required"
      readNewOrgName
    fi
    if [ "$CHAINCODE_NAME" == "" ]; then
      echo "New organisation name is required"
      readChaincodeName
    fi
    if [ "$CHAINCODE_VERSION" == "" ]; then
      echo "New organisation name is required"
      readChaincodeVersion
    fi
    CLI_CONTAINER=$(docker ps |grep ${DOCKER_STACK_NAME}_cli|awk '{print $1}')
    if [ "$CLI_CONTAINER" == "" ]; then
      echo "Failed to get the container .. try giving correct stack name"
      exit 1
    fi
    echo $CLI_CONTAINER
    docker exec ${CLI_CONTAINER} ./scripts/networkscripts/upgradechaincode.sh $NEW_ORG_NAME $CHANNEL_NAME $CHAINCODE_NAME $CHAINCODE_VERSION $ORDERER_TYPE
}















# Obtain the OS and Architecture string that will be used to select the correct
# native binaries for your platform
OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
# timeout duration - the duration the CLI should wait for a response from
# another container before giving up
CLI_TIMEOUT=10
#default for delay
CLI_DELAY=3
# use this file as the default docker-compose yaml definition
STACK_COMPOSE_FILE=docker-compose.yaml
# Docker default stack name to deploy in swarm mode
DOCKER_STACK_NAME=
# Docker default external network name
EXTERNAL_NETWORK=
# Parse commandline args
DOMAIN=Patients
DB=couchdb
ORDERER_TYPE=kafka
while getopts "h?m:c:t:d:e:s:b:n:v:o:k:" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    m)  MODE=$OPTARG
    ;;
    c)  CHANNEL_NAME=$OPTARG
    ;;
    t)  CLI_TIMEOUT=$OPTARG
    ;;
    d)  CLI_DELAY=$OPTARG
    ;;
    e)  EXTERNAL_NETWORK=$OPTARG
    ;;
    s)  DOCKER_STACK_NAME=$OPTARG
    ;;
    b)  DB=$OPTARG
    ;;
    n)  CHAINCODE_NAME=$OPTARG
    ;;
    v)  CHAINCODE_VERSION=$OPTARG
    ;;
    o)  NEW_ORG_NAME=$OPTARG
    ;;
    k)  ORDERER_TYPE=$OPTARG
    ;;
  esac
done

# Determine whether starting, stopping or generating for announce
if [ "$MODE" == "build" ]; then
  EXPMODE="Building"
  elif [ "$MODE" == "entirebuild" ]; then
  EXPMODE="Building Entire Network from Scarch"
  elif [ "$MODE" == "down" ]; then
  EXPMODE="Stopping"
  elif [ "$MODE" == "generate" ]; then
  EXPMODE="Generating certs and genesis block for"
  elif [ "$MODE" == "recreate" ]; then
  EXPMODE="Recreating Containers"
  elif [ "$MODE" == "start" ]; then
  EXPMODE="Starting Containers"
  elif [ "$MODE" == "stop" ]; then
  EXPMODE="Stopping Containers"
  elif [ "$MODE" == "addorg" ]; then
  EXPMODE="Adding new organisaion to the network"
  elif [ "$MODE" == "upgradechaincode" ]; then
  EXPMODE="upgrading chaincode"
else
  printHelp
  exit 1
fi

# Announce what was requested
echo "${EXPMODE} with channel '${CHANNEL_NAME}' and CLI timeout of '${CLI_TIMEOUT}' in docker swarm mode , external network '${EXTERNAL_NETWORK}' and stack name '${DOCKER_STACK_NAME}'"

# ask for confirmation to proceed
askProceed

#Create the network using docker compose
if [ "${MODE}" == "build" ]; then
  networkBuild
  elif [ "${MODE}" == "entirebuild" ]; then
  entireNetworkBuild
  elif [ "${MODE}" == "down" ]; then ## Clear the network
  networkDown
  elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
  generateCerts
  replacePrivateKey
  generateChannelArtifacts
  elif [ "${MODE}" == "addorg" ]; then ## adding new organisation
  addorg
  elif [ "${MODE}" == "upgradechaincode" ]; then ## upgrading chaincode
  upgradechaincode
  elif [ "${MODE}" == "recreate" ]; then ## recreate containers
  recreateContainers
  elif [ "${MODE}" == "start" ]; then ## start containers
  start
  elif [ "${MODE}" == "stop" ]; then ## stop containers
  stop
else
  printHelp
  exit 1
fi
