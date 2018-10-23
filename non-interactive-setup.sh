#!/bin/bash

POSITIONAL=()
while [[ $# -gt 0 ]]; do
key="$1"
    case $key in
        -h|--help)
        HELP=YES
        shift # past argument
        ;;
        -n|--hostname)
        NIFI_HOST="$2"
        shift # past argument
        shift # past value
        ;;
        -p|--port)
        NIFI_PORT="$2"
        shift # past argument
        shift # past value
        ;;
        -k|--keystore)
        KEYSTORE="$2"
        shift # past argument
        shift # past value
        ;;
        --key-pass)
        KEYSTORE_PASS="$2"
        shift # past argument
        shift # past value
        ;;
        -t|--truststore)
        TRUSTSTORE="$2"
        shift # past argument
        shift # past value
        ;;
        --trust-pass)
        TRUSTSTORE_PASS="$2"
        shift # past argument
        shift # past value
        ;;
        --ext-trust)
        GENERATE_EXT_TRUSTSTORE=YES
        shift # past argument
        ;;
        --ext-pass)
        EXT_TRUSTSTORE_PASS="$2"
        shift # past argument
        shift # past value
        ;;
        -c|--client-dn)
        CLIENT_DN="$2"
        shift # past argument
        shift # past value
        ;;
        --client-pass)
        CLIENT_PASS="$2"
        shift # past argument
        shift # past value
        ;;
        -s|--server-dn)
        SERVER_DN="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

print_help(){
    # TODO: print out help
    cat << EOF
This script generate appropriate configuration and keystore/truststore for a secure Nifi instance.

USAGE: ./setup.sh [OPTIONS]
Example: ./setup.sh -n host-01 -p 8443 -c "CN=admin, OU=nifi" -s "CN=host-01,OU=nifi"

OPTIONS:

    -h, --help:               Show the help message.
    -n, --hostname HOSTNAME:  Required. The hostname of machine hosting the Nifi container.
    -p, --port PORT:          Required. The forwarded port to the Nifi UI.
    -k, --keystore FILE:      Optional. The keystore file to be used in Nifi. If this argument is set, --keypass must also be set. If not specified, a new one will be generated.
    --keypass PASSWORD:       Optional. The password to keystore. If -k is not specified, this will be the password for the new generated keystore.If not specified, a random one will be used.
    -t, --truststore FILE:    Optional. The truststore file to be used in Nifi. If this argument is set, --trustpass must also be set. If not specified, a new one will be generated.
    --trustpass PASSWORD:     Optional. The password to keystore. If -t is not specified, this will be the password for the new generated truststore. If not specified, a random one will be used.
    --ext-trust:              Optional. Whether to generate a truststore from the keystore, which is intended to be used by another Nifi instance to communicate with this one.
    --ext-pass PASSWORD:      Optional. The password to the external truststore. If not specified, a random one is used.
    --client-pass PASSWORD:   Optional. The password to the client key file. If not specified, a random one is used.
    -s, --server-dn DN:       Optional. The Distinguish Name of the server certificate in keystore (Default: CN=[HOSTNAME],OU=nifi).
    -c, --client-dn DN:       Optional. The Distinguish Name of the client certificate in truststore (Default: CN=user ,OU=nifi).
EOF
}

gen_pass(){
    echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
}

# Check the correctness of arguments
if [ ! -z "${HELP}" ]; then
    print_help
    exit 0
fi
if [ -z "${NIFI_HOST}" ]; then
    echo "[ERROR] \"-n | --hostname\" is not specified "
    print_help
    exit 1
fi
if [ -z "${NIFI_PORT}" ]; then
    echo "[ERROR] \"-p | --port\" is not specified "
    print_help
    exit 1
fi
if [ ! -z "${KEYSTORE}" -a -z "${KEYSTORE_PASS}" ]; then
    echo "[ERROR] keystore specified but no keystore pass is given"
    print_help
    exit 1
fi
if [ ! -z "${TRUSTSTORE}" -a -z "${TRUSTSTORE_PASS}" ]; then
    echo "[ERROR] truststore specified but no truststore pass is given"
    print_help
    exit 1
fi
if [ -f ./secrets/keystore.jks -a -z "${KEYSTORE_PASS}" ]; then
    echo "[ERROR] keystore exists but no password is given"
    exit 1
fi
if [ -f ./secrets/truststore.jks -a -z "${TRUSTSTORE_PASS}" ]; then
    echo "[ERROR] truststore exists but no password is given"
    exit 1
fi
if [ ! -z "${KEYSTORE}" -a ! -f "${KEYSTORE}" ]; then
    echo "[ERROR] ${KEYSTORE} does not exist."
    exit 1
fi
if [ ! -z "${TRUSTSTORE}" -a ! -f "${TRUSTSTORE}" ]; then
    echo "[ERROR] ${TRUSTSTORE} does not exist."
    exit 1
fi
if [ \( -f ./secrets/keystore.jks -a ! -z "${KEYSTORE}" \) -o \( -f ./secrets/truststore.jks -a ! -z "${TRUSTSTORE}" \) ]; then
    echo "[ERROR] Keystore or truststore specified, but they already exists in ./secrets. Please remove the ones in ./secrets before continuing"
    exit 1
fi

# Give default values
: ${CLIENT_DN:="CN=user, OU=nifi"}
: ${SERVER_DN:="CN=${NIFI_HOST},OU=nifi"}
: ${KEYSTORE_PASS:=$(gen_pass)}
: ${TRUSTSTORE_PASS:=$(gen_pass)}
: ${GENERATE_EXT_TRUSTSTORE:=NO}
: ${EXT_TRUSTSTORE_PASS:=$(gen_pass)}
: ${CLIENT_PASS:=$(gen_pass)}

# Generate keystore/truststore
if [ ! -z "${KEYSTORE}" ]; then
    mv -f "${KEYSTORE}" ./secrets/keystore.jks
fi

if [ ! -z "${TRUSTSTORE}" ]; then
    mv -f "${TRUSTSTORE}" ./secrets/truststore.jks
fi

docker run -it --rm -v "$PWD/secrets":/usr/src/secrets \
        -w /usr/src/secrets --user ${UID} openjdk:8-alpine \
        /usr/src/secrets/generate-non-interactive.sh \
        "${SERVER_DN}" "${KEYSTORE_PASS}" \
        "${CLIENT_DN}" "${TRUSTSTORE_PASS}" \
        "${GENERATE_EXT_TRUSTSTORE}"  "${EXT_TRUSTSTORE_PASS}" \
        "${CLIENT_PASS}"


echo "Setting up .env file..."
cat << EOF > ./.env
AUTH=tls
INITIAL_ADMIN_IDENTITY=${CLIENT_DN}
KEYSTORE_PATH=/opt/secrets/keystore.jks
KEYSTORE_TYPE=JKS
KEYSTORE_PASSWORD=${KEYSTORE_PASS}
TRUSTSTORE_PATH=/opt/secrets/truststore.jks
TRUSTSTORE_PASSWORD=${TRUSTSTORE_PASS}
TRUSTSTORE_TYPE=JKS
NIFI_WEB_PROXY_HOST=${NIFI_HOST}:${NIFI_PORT}
NIFI_WEB_HTTP_HOST=${NIFI_HOST}
NIFI_REMOTE_INPUT_HOST=${NIFI_HOST}
EOF


echo "~~~~~~~~~~~~~~~~~~~~~~~"
echo "  Setup is done!"
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