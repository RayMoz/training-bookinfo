#!/bin/bash
#
# Quick reset to the OOTB settings
# This script will simple remove all the instanafied files in the and execute the docker build process again
# to enable a quick reset to square 1.
set -o errexit

if [ "$#" -ne 1 ]; then
    echo "Incorrect parameter"
    echo "Usage: reset.sh <prefix>"
    exit 1
fi

PREFIX=$1
# The Ruby part
echo "Reseting Ruby"
cd ../src/details
cp details-base.rb details.rb
cp Dockerfile-base Dockerfile

# Python
echo "Reseting Python"
cd ../productpage
cp requirements-base.txt requirements.txt
cp Dockerfile-base Dockerfile

# node.js
echo "Reseting node.js"
cd ../ratings
cp package-base.json package.json
cp ratings-base.js ratings.js

# build containers
echo "Rebuilding containers"
cd ..
./build-services.sh 1.0 ${PREFIX}

# update docker-compose file
echo "Preparing the docker-compose file"
cd ..
cp docker-compose-base.yaml docker-compose.yaml

# start up everything again
echo "Starting the show"
docker-compose up -d

echo "Done reseting the environment. Now you can start from scratch if you like."
