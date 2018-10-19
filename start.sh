#!/bin/bash

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

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Secure Nifi with cert-based authentication"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


# Generate client key & cert and add cert to truststore
if [ ! -f ./secrets/truststore.jks ]; then
    echo "truststore.jks does not exist. Generating truststore.jks with new client cert"
    docker run -it --rm -v "$PWD/secrets":/usr/src/secrets \
        -w /usr/src/secrets --user ${UID} openjdk:8-alpine \
        /usr/src/secrets/generate-truststore.sh \
        "${DNAME}" "${NIFI_TRUSTSTORE_PASS}"
    echo "Generation done! You can find the client PKCS12 file under:"
    echo "   ./secrets/client.p12"
    echo " "
fi

if [ ! -f ./secrets/keystore.jks ]; then
    echo "keystore.jks does not exist. Do you want to generate a new keystore with self-signed certificate?"
    select yn in "Yes" "No"; do
        case ${yn} in
            Yes )
                read -p "Please enter the subject of cert. It typically has the form \"CN=hostname,O=Fraunhofer FIT,C=DE\":" SERVER_CERT_SUBJECT
                read -p "Please enter the password for the keystore: " NIFI_KEYSTORE_PASS
                echo "Generating certificate with subject field: ${SERVER_CERT_SUBJECT}"
                docker run -it --rm -v "$PWD/secrets":/usr/src/secrets \
                    -w /usr/src/secrets --user ${UID} openjdk:8-alpine \
                    /usr/src/secrets/generate-keystore.sh \
                    "${SERVER_CERT_SUBJECT}" "${NIFI_KEYSTORE_PASS}"
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

if [[ "$(docker images -q ${DOCKER_IMAGE_TAG} 2> /dev/null)" == "" ]]; then
  # If specified image tag doesn't exist, build the image
  docker build -t ${DOCKER_IMAGE_TAG} .
fi


docker run --name ${DOCKER_CONTAINER_NAME} -p ${NIFI_PORT}:8443 \
    -v "${PWD}/secrets:/opt/secrets" \
    -e AUTH=tls \
    -e INITIAL_ADMIN_IDENTITY="${DNAME}" \
    -e KEYSTORE_PATH=/opt/secrets/keystore.jks \
    -e KEYSTORE_TYPE=JKS \
    -e KEYSTORE_PASSWORD="${NIFI_STORE_PASS}" \
    -e TRUSTSTORE_PATH=/opt/secrets/truststore.jks \
    -e TRUSTSTORE_PASSWORD="${NIFI_STORE_PASS}" \
    -e TRUSTSTORE_TYPE=JKS \
    -e NIFI_WEB_PROXY_HOST=${NIFI_HOST}:${NIFI_PORT} \
    -e NIFI_WEB_HTTP_HOST=${NIFI_HOST} \
    -e NIFI_REMOTE_INPUT_HOST=${NIFI_HOST} \
    ${DOCKER_IMAGE_TAG}