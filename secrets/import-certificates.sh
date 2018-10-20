#!/bin/ash

KEY_FILE=$1
PSWD=$2

keytool -import -file "$KEY_FILE" -alias nifi -keystore truststore.jks -storepass "$PSWD" -noprompt
chmod 640 truststore.jks

