#!/bin/bash -e

#-------------------------------------------
# DNAME of client certificate
# IMPORTANT: the empty space between different components is NECESSARY!
#-------------------------------------------
DNAME="CN=john.doe, OU=example, O=Fraunhofer FIT, L=Sankt Augustin, ST=Nordrhein Westfalen, C=DE"

#-------------------------------------------
# The hostname of the container host machine and the forwarded port to Nifi web interface
# These parameters allows a secure Nifi to accept HTTP request sent to ${NIFI_HOST}:${NIFI_PORT}, useful when Nifi is running behind a proxy or in a container.
#-------------------------------------------
NIFI_HOST=ucc-ipc-0
NIFI_PORT=5443

#-------------------------------------------
# Nifi keystore/truststore password
# The password to the keystore.jks and truststore.jks
#-------------------------------------------
NIFI_KEYSTORE_PASS=fraunhofer
NIFI_TRUSTSTORE_PASS=fraunhofer

#-------------------------------------------
# General settings
#-------------------------------------------
DOCKER_IMAGE_TAG=secure-nifi
DOCKER_CONTAINER_NAME=secure-nifi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Do not modify the lines below!
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "------------------------------------------"
echo "Secure Nifi with cert-based authentication"
echo "------------------------------------------"

# If an old .env file exists, remove it
if [ -f ./.env ]; then
    rm -f ./.env
fi


# Generate client key & cert and add cert to truststore
if [ ! -f ./secrets/truststore.jks ]; then
    echo "truststore.jks does not exist. Generating truststore.jks with new client cert"
    echo "---------------------------------------------"
    echo "Generating truststore with subject field: ${DNAME}"
    echo "---------------------------------------------"
    docker run -it --rm -v "$PWD/secrets":/usr/src/secrets \
        -w /usr/src/secrets --user ${UID} openjdk:8-alpine \
        /usr/src/secrets/generate-truststore.sh \
        "${DNAME}" "${NIFI_TRUSTSTORE_PASS}"
    echo "---------------------------------------------"
    echo "Truststore generation finished!"
    echo "---------------------------------------------"
fi

if [ ! -f ./secrets/keystore.jks ]; then
    echo "keystore.jks does not exist. Do you want to generate a new keystore with self-signed certificate? (Type the number before the option to choose):"
    select yn in "Yes" "No"; do
        case ${yn} in
            Yes )
                read -p "Please enter the subject of cert. It typically has the form \"CN=hostname,O=Fraunhofer FIT,C=DE\":" SERVER_CERT_SUBJECT
                echo -n "Please enter the password for the keystore: "
                read -s NIFI_KEYSTORE_PASS
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
                break
                ;;
            No )
                echo "keystore.jks does not exist. Please provides your keystore in ./secrets, or use the provided script to generate a new one"
                echo "[ERROR] No keystore.jks found. Launching aborted!"
                echo " "
                exit 1
                ;;
        esac
    done
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