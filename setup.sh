#!/bin/bash -e

echo " ----------------------------------------------"
echo "|                                              |"
echo "|  Secure Nifi with cert-based authentication  |"
echo "|                                              |"
echo " ----------------------------------------------"

# Function to generate random password
gen_pass(){
    echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
}

# If an old .env file exists, remove it
if [ -f ./.env ]; then
    rm -f ./.env
fi

read -p "The hostname of the machine running Nifi container:" NIFI_HOST
read -p "The host's forwarded port to the Nifi UI: " NIFI_PORT

if [ -f ./secrets/keystore.jks ]; then
    echo -n "keystore.jks detected. Please provide the password for the the keystore: "
    read -s NIFI_KEYSTORE_PASS
    echo " "
else
    NIFI_KEYSTORE_PASS=$(gen_pass)
fi

if [ -f ./secrets/truststore.jks ]; then
    echo -n "truststore.jks detected. Please provide the password for the the truststore: "
    read -s NIFI_TRUSTSTORE_PASS
    echo " "
else
    NIFI_TRUSTSTORE_PASS=$(gen_pass)
fi
echo "Please enter the DN of client. It typically has the form \"CN=user, OU=nifi\""
read -p "IMPORTANT: the SPACE between components must be provided as the example above:" CLIENT_DNAME

# Run the script to generate keystore/truststore, if they don't exist
docker run -it --rm -v "$PWD/secrets":/usr/src/secrets \
        -w /usr/src/secrets --user ${UID} openjdk:8-alpine \
        /usr/src/secrets/generate.sh \
        "${NIFI_KEYSTORE_PASS}" "${CLIENT_DNAME}" "${NIFI_TRUSTSTORE_PASS}"

echo "Setting up .env file..."
cat << EOF > ./.env
AUTH=tls
INITIAL_ADMIN_IDENTITY=${CLIENT_DNAME}
KEYSTORE_PATH=/opt/secrets/keystore.jks
KEYSTORE_TYPE=JKS
KEYSTORE_PASSWORD=${NIFI_KEYSTORE_PASS}
TRUSTSTORE_PATH=/opt/secrets/truststore.jks
TRUSTSTORE_PASSWORD=${NIFI_TRUSTSTORE_PASS}
TRUSTSTORE_TYPE=JKS
NIFI_WEB_PROXY_HOST=${NIFI_HOST}:${NIFI_PORT}
NIFI_WEB_HTTP_HOST=${NIFI_HOST}
NIFI_REMOTE_INPUT_HOST=${NIFI_HOST}
EOF

echo "~~~~~~~~~~~~~~~~~~~~~~~"
echo "Setup is done!"
echo "~~~~~~~~~~~~~~~~~~~~~~~"
echo "You can now run:"
echo " "
echo "   docker build -t secure-nifi ."
echo " "
echo "to build the image. Then use this command to run the container:"
echo " "
echo "   docker run --name secure-nifi --env-file ./.env -p ${NIFI_PORT}:8443 --detach secure-nifi"
echo " "
echo "To visit the Nifi UI, you need to import the client key into your browser. The key file is located in:"
echo " "
echo "   ./secrets/client.p12"
echo " "
echo "After importing, you can visit the following URL for the Nifi UI:"
echo " "
echo "   https://${NIFI_HOST}:${NIFI_PORT}/nifi"
echo " "
echo "Happy flowing!"
echo " "
echo " "