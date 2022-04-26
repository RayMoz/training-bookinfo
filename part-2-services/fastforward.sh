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
cp details-instana.rb details.rb
cp Dockerfile-instana Dockerfile

# Python
echo "Preparing Python"
cd ../productpage
cp requirements-instana.txt requirements.txt
cp Dockerfile-instana Dockerfile

# node.js
echo "Preparing node.js"
cd ../ratings
cp package-instana.json package.json
cp ratings-instana.js ratings.js

# build containers
echo "Building containers"
cd ..
./build-services.sh 1.0 ${PREFIX}

# update docker-compose file
echo "Updating docker-compose file"
cd ..
cp docker-compose-instana.yaml docker-compose.yaml

## create new .env file with the tag and the prefix given here
echo "Updating .env file"
cat <<EOF > .env
# environment file for docker-compose
REPO=${PREFIX}
TAG=1.0
EOF

# start up everything
docker-compose up -d

echo "Ready. Done setting up the environment. Please deploy the agent now and then: Have fun configuring the services."
