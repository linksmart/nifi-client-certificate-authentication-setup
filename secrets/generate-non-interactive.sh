#!/bin/ash -e

SERVER_DNAME=$1
KEYSTORE_PSWD=$2
CLIENT_DNAME=$3
TRUSTSTORE_PSWD=$4
GENERATE_EXT_TRUSTSTORE=$5
EXT_TRUSTSTORE_PSWD=$6
CLIENT_PSWD=$7

if [ ! -f ./secrets/keystore.jks ]; then
    echo "keystore.jks does not exist. Generating new keystore."
    echo "*** Generating keystore with certificate \"${SERVER_DNAME}\" ***"
    keytool -genkey -keyalg RSA -alias nifi -keystore keystore.jks -keypass "${KEYSTORE_PSWD}" -storepass "${KEYSTORE_PSWD}" -validity 365 -keysize 4096 -dname "${SERVER_DNAME}"
    chmod 640 keystore.jks

    # Generate a truststore for this keystore, so that it could be easily used on other Nifi instances to communicate with this Nifi instance securely
    if [ "${GENERATE_EXT_TRUSTSTORE}" == "YES" ]; then
        echo "*** Generating EXTERNAL truststore ***"
        rm -f external.der
        rm -f external_truststore.jks
        keytool -export -keystore keystore.jks -alias nifi -file external.der -storepass "${KEYSTORE_PSWD}"
        keytool -import -file external.der -alias nifi -keystore external_truststore.jks -storepass "${EXT_TRUSTSTORE_PSWD}" -noprompt
        echo "${EXT_TRUSTSTORE_PSWD}" > ./external_truststore.pass
        rm -f external.der
        chmod 640 external_truststore.jks
    fi

    echo "*** Keystore generation finished! ***"
fi

# Generate a JKS keystore first
if [ ! -f ./truststore.jks ]; then


    # Generate truststore and client key
    echo "truststore.jks does not exist. Generating new truststore.jks"
    echo "*** Generating truststore with certificate \"${CLIENT_DNAME}\" ***"
    # First generate a keystore
    keytool -genkey -keyalg RSA -alias client -keystore client_keystore.jks -keypass "${TRUSTSTORE_PSWD}" -storepass "${TRUSTSTORE_PSWD}" -validity 365 -keysize 4096 -dname "${CLIENT_DNAME}"

    # Export certificate and put it into truststore
    keytool -export -keystore client_keystore.jks -alias client -file client.der -storepass "${TRUSTSTORE_PSWD}"
    keytool -import -file client.der -alias client -keystore truststore.jks -storepass "${TRUSTSTORE_PSWD}" -noprompt

    # Generate pkcs12 file from client_keystore.jks
    rm -f client.p12
    keytool -importkeystore -srckeystore client_keystore.jks -destkeystore client.p12 \
      -srcstoretype JKS -deststoretype PKCS12 -srcstorepass "${TRUSTSTORE_PSWD}" -deststorepass "${CLIENT_PSWD}" -destkeypass "${CLIENT_PSWD}" \
      -srcalias client -destalias client
    echo "${CLIENT_PSWD}" > ./client.pass

    # Clean up
    rm -f client_keystore.jks
    rm -f client.der
    chmod 640 client.p12
    chmod 640 truststore.jks
fi




