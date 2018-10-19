#!/bin/ash

DNAME=$1
PSWD=$2

apk --update add openssl

echo "Generating truststore"
# Generate client private key and certificate
openssl req -newkey rsa:4096 -nodes -keyout key.pem -x509 -days 365 -out cert.pem -subj ${DNAME}

# Put client certificate into truststore
keytool -import -file cert.pem -alias client -keystore truststore.jks -storepass "$PSWD" -noprompt

# Generate pkcs12 file from key and certificate
openssl pkcs12 -export -in cert.pem -inkey key.pem -out client.p12 -password fraunhofer -name nifi

rm -f key.pem
rm -f cert.pem
chmod 640 client.p12
chmod 640 truststore.jks
