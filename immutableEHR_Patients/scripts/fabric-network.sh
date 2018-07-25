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

# prepending $PWD/bin/bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
export PATH=${PWD}/${FABRIC_BINARIES_DIRECTORY}/bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  ./fabric-network.sh -m build|down|generate [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>]"
  echo "  ./fabric-network.sh -h|--help (print this message)"
  echo "    -m <mode> - one of 'build', 'start', 'stop', 'down', 'recreate' or 'generate'"
  echo "      - 'build' - build the network with already existing certificates"
  echo "      - 'entirebuild' - build the network: generate required certificates and genesis block & create all containers needed for the network"
  echo "      - 'down' - remove the network containers"
  echo "      - 'generate' - generate required certificates and genesis block"
  echo "      - 'recreate' - recreate containers"
  echo "      - 'start' - start the containers"
  echo "      - 'stop' - stop the containers"
  echo "    -c <channel name> - channel name to use (defaults to \"$CHANNEL_NAME\")"
  echo "    -t <timeout> - CLI timeout duration in microseconds (defaults to 10000)"
  echo "    -d <delay> - delay duration in seconds (defaults to 3)"
  echo "    -f <docker-compose-file> - specify which docker-compose file use (defaults to docker-compose.yaml)"
  echo
  echo "Typically for the first time, one would first generate the required certificates and "
  echo "genesis block, then build the network.:"
  echo
  echo "	./fabric-network.sh -m build"

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
}

# Generate the needed certificates, the genesis block and start the network.
function networkBuild () {
  # generate artifacts if they don't exist
  if [ ! -d "crypto-config" ]; then
    generateCerts
    replacePrivateKey
    generateChannelArtifacts
  fi

  # Ask Context
  askContext

  CLI_COMPOSE_FILE_TEMPLATE=docker-compose-base/docker-compose-cli-template.yaml

  cp "$CLI_COMPOSE_FILE_TEMPLATE" "$CLI_COMPOSE_FILE"

  # sed on MacOSX does not support -i flag with a null extension. We will use
  # 't' for our back-up's extension and depete it at the end of the function
  ARCH=`uname -s | grep Darwin`
  if [ "$ARCH" == "Darwin" ]; then
    OPTS="-it"
  else
    OPTS="-i"
  fi

  # add network name
  sed $OPTS "s/NETWORK-NAME:/${HYPERLEDGER_FRAMEWORK_NAME}:/g" "$CLI_COMPOSE_FILE"
  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm "${CLI_COMPOSE_FILE}t"
  fi

  # replace volume names
  sed $OPTS "s/.DOMAIN:/.${DOMAIN}:/g" "$CLI_COMPOSE_FILE"
  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm "${CLI_COMPOSE_FILE}t"
  fi

  # Copy the template to the file that will be modified
  cp "$CLI_COMPOSE_FILE" "$COMPOSE_FILE"

  # remove unused configurations
  sed $OPTS '/cli:/,/- fabric/d' $COMPOSE_FILE
  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm "${COMPOSE_FILE}t"
  fi

  # remove ledger data
  rm -rf ./ledger

  CHANNEL_NAME=$CHANNEL_NAME TIMEOUT=$CLI_TIMEOUT DELAY=$CLI_DELAY docker-compose -f $CLI_COMPOSE_FILE up -d 2>&1

  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start network"
    docker logs -f cli.$DOMAIN
    exit 1
  fi
  docker logs -f cli.$DOMAIN

}

# Tear down running network
function networkDown () {
    docker-compose -f $CLI_COMPOSE_FILE down
    #Cleanup the chaincode containers
    clearContainers
    #Cleanup images
    removeUnwantedImages

    # Remove docker network
    docker network rm ${FABRIC_DOCKER_NETWORK_NAME}

    # remove orderer block and other channel configuration transactions and certs
    rm -rf $CHANNEL_ARTIFACTS_PATH crypto-config crypto-config.yaml configtx.yaml
    # remove the docker-compose yaml files that was customized
    rm -f $COMPOSE_CA_FILE $COMPOSE_FILE $CLI_COMPOSE_FILE

    # remove ledger data
    rm -rf ./ledger
}

# Using docker-compose-ca-base-template.yaml, replace constants with private key file names
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

  # Copy the template to the file that will be modified to add the private key
  cp "$COMPOSE_CA_TEMPLATE" "$COMPOSE_CA_FILE"

  # The next steps will replace the template's contents with the
  # actual values of the private key file names for the two CAs.
  CURRENT_DIR=$PWD
  cd crypto-config/peerOrganizations/org1.$DOMAIN/ca/
  PRIV_KEY=$(ls *_sk)
  cd "$CURRENT_DIR"
  sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" "$COMPOSE_CA_FILE"
  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm "$COMPOSE_CA_BACKUP_FILE"
  fi
}

# We will use the cryptogen tool to generate the cryptographic material (x509 certs)
# for our various network entities.  The certificates are based on a standard PKI
# implementation where validation is achieved by reaching a common trust anchor.
#
# Cryptogen consumes a file - ``crypto-config.yaml`` - that contains the network
# topology and allows us to generate a library of certificates for both the
# Organizations and the components that belong to those Organizations.  Each
# Organization is provisioned a unique root certificate (``ca-cert``), that binds
# specific components (peers and orderers) to that Org.  Transactions and communications
# within Fabric are signed by an entity's private key (``keystore``), and then verified
# by means of a public key (``signcerts``).  You will notice a "count" variable within
# this file.  We use this to specify the number of peers per Organization; in our
# case it's two peers per Org.  The rest of this template is extremely
# self-explanatory.
#
# After we run the tool, the certs will be parked in a folder titled ``crypto-config``.

# Generates Org certs using cryptogen tool
function generateCerts (){
  which cryptogen
  if [ "$?" -ne 0 ]; then
    echo "cryptogen tool not found. exiting"
    exit 1
  fi
  echo
  echo "##########################################################"
  echo "##### Generate certificates using cryptogen tool #########"
  echo "##########################################################"
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
  cp ./config-templates/crypto-config-template.yaml crypto-config.yaml

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

# The `configtxgen tool is used to create four artifacts: orderer **bootstrap
# block**, fabric **channel configuration transaction**
#
# The orderer block is the genesis block for the ordering service, and the
# channel transaction file is broadcast to the orderer at channel creation
# time.
#
# Configtxgen consumes a file - ``configtx.yaml`` - that contains the definitions
# for the sample network. There are three members - one Orderer Org (``OrdererOrg``)
# and two Peer Orgs (``Org1``) each managing and maintaining two peer nodes.
# This file also specifies a consortium - ``SampleConsortium`` - consisting of our
# two Peer Orgs.  Pay specific attention to the "Profiles" section at the top of
# this file.  You will notice that we have two unique headers. One for the orderer genesis
# block - ``OneOrgOrdererGenesis`` - and one for our channel - ``OneOrgChannel``.
# These headers are important, as we will pass them in as arguments when we create
# our artifacts.
#
# This function will generate the crypto material and our four configuration
# artifacts, and subsequently output these files into the ``$CHANNEL_ARTIFACTS_PATH``
# folder.
#
# If you receive the following warning, it can be safely ignored:
#
# [bccsp] GetDefault -> WARN 001 Before using BCCSP, please call InitFactories(). Falling back to bootBCCSP.
#
# You can ignore the logs regarding intermediate certs, we are not using them in
# this crypto implementation.

# Generate orderer genesis block and channel configuration transaction
function generateChannelArtifacts() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  echo "creating $CHANNEL_ARTIFACTS_PATH folder..."
  rm -rf ./$CHANNEL_ARTIFACTS_PATH
  mkdir ./$CHANNEL_ARTIFACTS_PATH

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
  cp ./config-templates/configtx-template.yaml configtx.yaml

  # The next steps will replace the template's contents with the
  # actual values of the domain name.
  sed $OPTS "s/DOMAIN/${DOMAIN}/g" "${CONFIGTX_FILE}"

  echo "##########################################################"
  echo "#########  Generating Orderer Genesis block ##############"
  echo "##########################################################"
  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
  configtxgen -profile OneOrgOrdererGenesis -outputBlock ./$CHANNEL_ARTIFACTS_PATH/$GENESIS_FILE_NAME
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate orderer genesis block..."
    exit 1
  fi
  echo
  echo "#########################################################################"
  echo "### Generating channel configuration transaction '$CHANNEL_FILE_NAME' ###"
  echo "#########################################################################"
  configtxgen -profile OneOrgChannel -outputCreateChannelTx ./$CHANNEL_ARTIFACTS_PATH/$CHANNEL_FILE_NAME -channelID $CHANNEL_NAME
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate channel configuration transaction..."
    exit 1
  fi

  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm "${CONFIGTX_FILE}t"
  fi

}

# Ask Context
function askContext () {
  read -p "Context: (dev/prod) " CONTEXT
  case "$CONTEXT" in
    dev|DEV )
      echo "Building for development..."
      FABRIC_LOGGING_LEVEL=DEBUG
      FABRIC_CA_ENABLE_DEBUG=-d
    ;;
    prod|PROD )
      echo "Building for production..."
      FABRIC_LOGGING_LEVEL=INFO
      FABRIC_CA_ENABLE_DEBUG=
    ;;
    * )
      echo "invalid context"
      askContext
    ;;
  esac
}


function recreateContainers() {
    # Ask Context
    askContext

    docker-compose down
    docker-compose up -d
}


function start() {
    # Ask Context
    askContext
    docker-compose start
}


function stop() {
    docker-compose stop
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
COMPOSE_FILE=docker-compose.yaml
# use this file to start cli container
CLI_COMPOSE_FILE=docker-compose-cli.yaml
#
COMPOSE_CA_TEMPLATE=docker-compose-base/docker-compose-ca-base-template.yaml
COMPOSE_CA_FILE=docker-compose-base/docker-compose-ca-base.yaml
COMPOSE_CA_BACKUP_FILE=docker-compose-base/docker-compose-ca-base.yamlt

# Parse commandline args
while getopts "h?m:c:t:d:f:" opt; do
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
    f)  COMPOSE_FILE=$OPTARG
    ;;
  esac
done

# Determine whether starting, stopping or generating for announce
if [ "$MODE" == "build" ]; then
  EXPMODE="Building"
  elif [ "$MODE" == "e" ]; then
  EXPMODE="Stopping"
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
else
  printHelp
  exit 1
fi

# Announce what was requested
echo "${EXPMODE} with channel '${CHANNEL_NAME}' and CLI timeout of '${CLI_TIMEOUT}' using database couchdb"

# ask for confirmation to proceed
askProceed

#Create the network using docker compose
if [ "${MODE}" == "build" ]; then
  networkBuild
  elif [ "${MODE}" == "down" ]; then ## Clear the network
  networkDown
  elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
  generateCerts
  replacePrivateKey
  generateChannelArtifacts
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
