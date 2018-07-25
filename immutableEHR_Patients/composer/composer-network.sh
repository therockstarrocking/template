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

    CA_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.example.com/ca/ca.${DOMAIN}.example.com-cert.pem)"
    ORDERER_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/ordererOrganizations/${DOMAIN}.example.com/orderers/orderer.${DOMAIN}.example.com/msp/tlscacerts/tlsca.${DOMAIN}.example.com-cert.pem)"
    PEER0_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.example.com/peers/peer0.${DOMAIN}.example.com/msp/tlscacerts/tlsca.${DOMAIN}.example.com-cert.pem)"
    PEER1_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/peerOrganizations/${DOMAIN}.example.com/peers/peer1.${DOMAIN}.example.com/msp/tlscacerts/tlsca.${DOMAIN}.example.com-cert.pem)"

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
        "orderer.example.com"
      ],
      "peers": {
        "peer0.${DOMAIN}.example.com": {
          "endorsingPeer": true,
          "chaincodeQuery": true,
          "ledgerQuery": true,
          "eventSource": true
        },
        "peer1.${DOMAIN}.example.com": {
          "endorsingPeer": true,
          "chaincodeQuery": true,
          "ledgerQuery": true,
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
        "ca-${DOMAIN}"
      ]
    }
  },
  "orderers": {
    "orderer.example.com": {
      "url": "grpcs://orderer.example.com:7050",
      "grpcOptions": {
        "ssl-target-name-override": "orderer.example.com",
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
    "peer0.${DOMAIN}.example.com": {
      "url": "grpcs://peer0.${DOMAIN}.example.com:7051",
      "eventUrl": "grpcs://peer0.${DOMAIN}.example.com:7053",
      "grpcOptions": {
        "ssl-target-name-override": "peer0.${DOMAIN}.example.com"
      },
      "tlsCACerts": {
        "pem": "${PEER0_CERT}"
      }
    },
    "peer1.${DOMAIN}.example.com": {
      "url": "grpcs://peer1.${DOMAIN}.example.com:7051",
      "eventUrl": "grpcs://peer1.${DOMAIN}.example.com:7053",
      "grpcOptions": {
        "ssl-target-name-override": "peer1.${DOMAIN}.example.com"
      },
      "tlsCACerts": {
        "pem": "${PEER1_CERT}"
      }
    }
  },
  "certificateAuthorities": {
    "ca_peer${DOMAIN}": {
      "url": "https://ca_peer${DOMAIN}:7054",
      "caName": "ca_peer${DOMAIN}",
      "tlsCACerts": {
        "pem": "${CA_CERT}"
      }
    }
  }
}
EOF

}
