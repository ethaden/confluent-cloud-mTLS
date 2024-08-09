#!/bin/bash
# This file reads data from

if [ -z "${TF_USER}" ]; then
  TF_USER="${USER}"
fi

if [ -z "${CONFLUENT_CLOUD_API_KEY}" -o -z "${CONFLUENT_CLOUD_API_SECRET}" ]; then
  CONFLUENT_API_KEY_FILE="api-key.txt"
  if [ -e ${CONFLUENT_API_KEY_FILE} ]; then
    export CONFLUENT_CLOUD_API_KEY=$(grep "API key:$" -A 1 ${CONFLUENT_API_KEY_FILE} | sed -n "2p")
    export CONFLUENT_CLOUD_API_SECRET=$(grep "API secret:$" -A 1 ${CONFLUENT_API_KEY_FILE} | sed -n "2p")
  # Comment the next three lines if this project does not use Confluent Cloud
  else
    printf "Please set environment variables CONFLUENT_CLOUD_API_KEY and CONFLUENT_CLOUD_API_SECRET or provide an API file ${CONFLUENT_API_KEY_FILE} as exported during creation by the confluent website\n" >&2
    exit 1
  fi
fi

if [ -n "${TF_REALNAME}" ]; then
    REALNAME="${TF_REALNAME}"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    REALNAME="$(getent passwd ${TF_USER} | cut -d: -f5)"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OSX
    REALNAME="$(dscl . -read /Users/${TF_USER} RealName | cut -d: -f2 | sed -e 's/^[ \t]*//' | grep -v "^$")"
fi

# If possible find the URL of the Github repo where this code lives
PROVENANCE=""
if command -v git &> /dev/null; then
  if REMOTE=$(git config --get remote.origin.url) 2>/dev/null; then
    PROVENANCE=${REMOTE}
  fi
fi
CURRENT_DATETIME=$(date -Iseconds)

# I prefer ed25519 keys if existing and fall back to RSA
PUBLIC_SSH_KEY=""
if [ -f "${HOME}/.ssh/id_ed25519.pub" ]; then
  PUBLIC_SSH_KEY=$(<"${HOME}/.ssh/id_ed25519.pub")
elif [ -f "${HOME}/.ssh/id_rsa.pub" ]; then
  PUBLIC_SSH_KEY=$(<"${HOME}/.ssh/id_rsa.pub")
fi

# Change the contents of this output to get the environment variables
# of interest. The output must be valid JSON, with strings for both
# keys and values.
if [ -z "${CONFLUENT_CLOUD_API_KEY}" -o -z "${CONFLUENT_CLOUD_API_SECRET}" ]; then
  # Do not use Confluent Cloud
  cat <<EOF
  {
    "user": "${TF_USER}",
    "owner_fullname": "${REALNAME}",
    "owner_email": "${TF_USER}@confluent.io",
    "provenance": "${PROVENANCE}",
    "current_datetime": "${CURRENT_DATETIME}",
    "public_ssh_key": "${PUBLIC_SSH_KEY}"
  }
EOF
else
  cat <<EOF
  {
    "user": "${TF_USER}",
    "owner_fullname": "${REALNAME}",
    "owner_email": "${TF_USER}@confluent.io",
    "provenance": "${PROVENANCE}",
    "current_datetime": "${CURRENT_DATETIME}",
    "api_key": "${CONFLUENT_CLOUD_API_KEY}",
    "api_secret": "${CONFLUENT_CLOUD_API_SECRET}",
    "public_ssh_key": "${PUBLIC_SSH_KEY}"
  }
EOF
fi
