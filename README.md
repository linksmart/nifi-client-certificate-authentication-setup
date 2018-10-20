# Nifi Certificate-based Authentication Setup

This repository provides configuration for setting up a secure Nifi instance
with client-side certificate-based authentication. Using this method, only 
browsers with the trusted client certificate can visit the Nifi UI. Username
password authentication is not allowed.

## Quick Start
Run the starting script to start the container. You can modify some parameters
inside this script:
```
./setup.sh
```
The script will set up necessary files for you. 
If you do not have a keystore under `./secrets` After the image is built, it will also ask help you to generate a new one.
After the script is run, you can now build the new Nifi image:
```bash
docker build -t secure-nifi .
```

you can run it by using the following command:
```bash
docker run --name secure-nifi --env-file ./.env -p [port]:8443 --detach secure-nifi
```
the variable `port` is the one you specified in `./setup.sh`  

After Nifi has finished starting up, you can visit Nifi with the following URL:
 ```
 https://localhost:[port]/nifi
 ```
 
## Advanced
1. If you have NAR files to add to the Nifi library, simply put them into `./nifi/nars`, they'll be copied into the newly built image in start-up.  

2. If you have configurations files to add to the Nifi instance, simply put them into `./nifi/conf`. Typically, you can put in the following files:
    - `flow.xml.gz`: this file contains the current processor setup on the Nifi canvas
    - `./templates/*.xml`: template files  
    
3. This repository also comes with some scripts to help you set up your keystore and truststore. 
To generate a new keystore with self-signed certificate, run the following command:
     ```bash
     docker run -it --rm -v "$PWD/secrets":/usr/src/secrets \
         -w /usr/src/secrets --user ${UID} openjdk:8-alpine \
         /usr/src/secrets/generate-certificates.sh \
         [DN of certificate] [store password]
     ```
     where `DN of certificate` typically has the following form:
     ```
     "CN=<hostname>,O=Fraunhofer FIT,L=Sankt Augustin,ST=Nordrhein Westfalen,C=DE"
     ```
     `store password` is the password to keystore. Remember to rebuild Nifi image and set the `NIFI_STORE_PASS` in `./scripts/setup.sh`
 
 ## Notes
 1. When you specify the `DNAME` environment variable in `./start.sh`, it is 
 **IMPORTANT** to leave **EMPTY SPACES** between components! E.g. `CN=john.doe, O=Fraunhofer, C=DE`.
 The reason is, this `DNAME` will be used as Nifi's `INITIAL_ADMIN_USER`.
 However, spaces will be inserted between components during certificate 
 generation and the resulted string is used as the certificate's subject field. 
 As a result, the cert's subject field fails to match the `INITIAL_ADMIN_USER` 
 completely, leading to Nifi not authorizing the certificate identity.