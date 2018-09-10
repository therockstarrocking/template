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
  echo "  addingorg.sh addorg|upgradechaincode| [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>]"
  echo "  addingorg.sh -h|--help (print this message)"
  echo "    <mode> - one of 'addorg', 'upgradechaincode', 'restart' or 'generate'"
  echo "      - 'addorg' - bring addorg the network with docker-compose addorg"
  echo "      - 'upgradechaincode' - clear the network with docker-compose upgradechaincode"
  echo "    -o <Domain name> - Specify the Domain name of the new organisation"
  echo "    -c <channel name> - channel name to use (defaults to \"mychannel\")"
  echo "    -t <timeout> - CLI timeout duration in seconds (defaults to 10)"
  echo "    -d <delay> - delay duration in seconds (defaults to 3)"
  echo "    -n <chaincode name> "
  echo "    -v <chaincoce version>"
  echo
  echo "	addingorg.sh addorg "
  echo "	addingorg.sh upgradechaincode -c immutableehr -n mycc -v 2.0"
  echo
  echo "Taking all defaults:"
  echo "	addingorg.sh addorg"
  echo "	addingorg.sh upgradechaincode"
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

function addorg () {
    cd $I_PATH
   CLI_CONTAINER=$(docker ps |grep ${STACK}_cli|awk '{print $1}')
   echo $CLI_CONTAINER
   docker exec ${CLI_CONTAINER} ./scripts/networkscripts/addneworg.sh $DOMAIN $CHANNEL_NAME $CLI_DELAY $CLI_TIMEOUT
}
function upgradechaincode () {
    cd $I_PATH
   CLI_CONTAINER=$(docker ps |grep ${STACK}_cli|awk '{print $1}')
   echo $CLI_CONTAINER
   docker exec ${CLI_CONTAINER} ./scripts/networkscripts/upgradechaincode.sh $DOMAIN $CHANNEL_NAME $CHAINCODE $VERSION
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
DOCKER_STACK_NAME=ehr
# Docker default external network name
EXTERNAL_NETWORK=byfh
# Parse commandline args
DOMAIN=XyzHospitals
DB=level
CHANNELNAME=immutableehr
CHAINCODE=mycc
VERSION=2.0

# Parse commandline args
if [ "$1" = "-m" ];then	# supports old usage, muscle memory is powerful!
    shift
fi
MODE=$1;shift
# Determine whether starting, stopping, restarting or generating for announce
if [ "$MODE" == "addorg" ]; then
  EXPMODE="Adding new Organisation"
elif [ "$MODE" == "upgradechaincode" ]; then
  EXPMODE="Upgrading chaincode"
else
  printHelp
  exit 1
fi
while getopts "h?o:s:c:t:d:n:v:" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    o)  DOMAIN=$OPTARG
    ;;
    s)  STACK=$OPTARG
    ;;
    c)  CHANNEL_NAME=$OPTARG
    ;;
    t)  CLI_TIMEOUT=$OPTARG
    ;;
    d)  CLI_DELAY=$OPTARG
    ;;
    n)  CHAINCODE=$OPTARG
    ;;
    v)  VERSION=$OPTARG
    ;;
  esac
done

if [ ! STACK ]; then
    echo "stack name not found"
    exit 1
fi
# Announce what was requested

echo "${EXPMODE} with channel '${CHANNEL_NAME}' and CLI timeout of '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds and using database couchdb"
  
# ask for confirmation to proceed
askProceed

#Create the network using docker compose
if [ "${MODE}" == "addorg" ]; then
  addorg
elif [ "${MODE}" == "upgradechaincode" ]; then ## Clear the network
  upgradechaincode
else
  printHelp
  exit 1
fi

