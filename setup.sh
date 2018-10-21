#!/bin/bash -e

echo "------------------------------------------"
echo "Secure Nifi with cert-based authentication"
echo "------------------------------------------"

# Function to generate random password
gen_pass(){
    echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
}

# If an old .env file exists, remove it
if [ -f ./.env ]; then
    rm -f ./.env
fi

read -p "The hostname of the machine running Nifi container:\n" NIFI_HOST
read -p "The host's forwarded port to the Nifi UI:\n" NIFI_PORT

# Generate client key & cert and add cert to truststore
if [ ! -f ./secrets/truststore.jks ]; then
    echo "truststore.jks does not exist. Generating new truststore.jks"
    echo "Please enter the subject of cert. It typically has the form \"CN=user, OU=nifi\""
    read -p "IMPORTANT: the SPACE between components must be provided as the example above:\n" DNAME
    echo "---------------------------------------------"
    echo "Generating truststore with subject field: ${DNAME}"
    echo "---------------------------------------------"
    NIFI_TRUSTSTORE_PASS=gen_pass
    echo -n "Please provide password for the client-side PCKS12 file: "
    read -s PKCS12_PASS
    docker run -it --rm -v "$PWD/secrets":/usr/src/secrets \
        -w /usr/src/secrets --user ${UID} openjdk:8-alpine \
        /usr/src/secrets/generate-truststore.sh \
        "${DNAME}" "${NIFI_TRUSTSTORE_PASS}" "${PKCS12_PASS}"
    echo "---------------------------------------------"
    echo "Truststore generation finished!"
    echo "---------------------------------------------"
else
    echo -n "truststore.jks detected. Please provide the password for the the truststore: "
    read -s NIFI_TRUSTSTORE_PASS
fi

if [ ! -f ./secrets/keystore.jks ]; then
    echo "keystore.jks does not exist. Generating new keystore."
    read -p "Please enter the subject of cert. It typically has the form \"CN=[hostname],OU=nifi\":" SERVER_CERT_SUBJECT
    NIFI_KEYSTORE_PASS=gen_pass
    echo " "
    echo "---------------------------------------------"
    echo "Generating certificate with subject field: ${SERVER_CERT_SUBJECT}"
    echo "---------------------------------------------"
    docker run -it --rm -v "$PWD/secrets":/usr/src/secrets \
        -w /usr/src/secrets --user ${UID} openjdk:8-alpine \
        /usr/src/secrets/generate-keystore.sh \
        "${SERVER_CERT_SUBJECT}" "${NIFI_KEYSTORE_PASS}"
    echo "---------------------------------------------"
    echo "Keystore generation finished!"
    echo "---------------------------------------------"
else
    echo -n "keystore.jks detected. Please provide the password for the the keystore: "
    read -s NIFI_KEYSTORE_PASS
fi

echo "Setting up .env file..."
cat << EOF > ./.env
AUTH=tls
INITIAL_ADMIN_IDENTITY=${DNAME}
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
echo "  docker build -t secure-nifi ."
echo " "
echo "to build the image. Then use this command to run the container:"
echo " "
echo "  docker run --name secure-nifi --env-file ./.env -p ${NIFI_PORT}:8443 --detach secure-nifi"
echo " "
echo "To visit the Nifi UI, you need to import the client key into your browser. The key file is located in:"
echo " "
echo "  ./secrets/client.p12"
echo " "
echo "After importing, you can visit https://${NIFI_HOST}:${NIFI_PORT}/nifi for the UI."
echo " "
echo "Happy flowing!"
echo " "
echo " "