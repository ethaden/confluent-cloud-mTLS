# Here, some important variables with credentials are initialized using an API key file provided by the user in ${HOME}/.confluent/api-key.txt
# Alternatively, just place an api-key.txt (or a symlink to one) in this folder (make sure it will not be commited to git, though!). My terraform configuration will read it.
# Use with: source env.sh
CONFLUENT_API_KEY_FILE="${HOME}/.confluent/api-key.txt"

if [ \! -e ${CONFLUENT_API_KEY_FILE} ]; then
  echo "Please provide an API file ${CONFLUENT_API_KEY_FILE} as exported during creation by the confluent website"
else
  export CONFLUENT_CLOUD_API_KEY=$(grep "API key:" -A 1 ${CONFLUENT_API_KEY_FILE} | sed -n "2p")
  export CONFLUENT_CLOUD_API_SECRET=$(grep "API secret:" -A 1 ${CONFLUENT_API_KEY_FILE} | sed -n "2p")
fi
