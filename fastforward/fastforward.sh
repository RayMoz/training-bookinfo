#!/bin/bash
#
# Quick setup for the second part
# This script will simple copy all the instanafied files in the right places and execute the docker build process
# to enable the quick prep for the 2nd part of the Training
set -o errexit

if [ "$#" -ne 1 ]; then
    echo "Incorrect parameter"
    echo "Usage: fastforward.sh <prefix>"
    exit 1
fi

PREFIX=$1

# The Ruby part
echo "Preparing Ruby"
cd ../src/details
cp details-otel.rb details.rb
cp Dockerfile-otel Dockerfile

# Python
echo "Preparing Python"
cd ../productpage
cp requirements-otel.txt requirements.txt
cp Dockerfile-otel Dockerfile

# node.js
echo "Preparing node.js"
cd ../ratings
cp Dockerfile-otel Dockerfile

# build containers
echo "Building containers"
cd ..
./build-services.sh 1.1 ${PREFIX}

# update docker-compose file
echo "Updating docker-compose file"
cd ..
cp docker-compose-otel.yaml docker-compose.yaml

## create new .env file with the tag and the prefix given here
echo "Updating .env file"
cat <<EOF > .env
#environment file for docker-compose
REPO=${PREFIX}
TAG=1.1
BACKEND=hostname
COLLECTOR_ENDPOINT=http://otel-collector
EOF

# start up everything
docker-compose up -d

echo "Ready. Done setting up the environment. Please check in your backend system if that data appears."
