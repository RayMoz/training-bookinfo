#!/bin/bash
#
# Quick reset to the OOTB settings
# This script will simple remove all the instanafied files in the and execute the docker build process again
# to enable a qucik reset to square 1.

# The Ruby part
cd ../src/details
cp details-base.rb details.rb
cp Dockerfile-base Dockerfile

# Python
cd ../productpage
cp requirements-base.txt requirements.txt
cp Dockerfile-base Dockerfile

# node.js

cd ../ratings
cp package-base.json package.json
cp ratings-base.js ratings.js

# build containers

cd ..
./build-service.sh

# update docker-compose file
cd ..
cp docker-compose-base.yaml docker-compose.yaml

# start up everything again

docker-compose up -d

echo "Done reseting the environment. Now you can start from scratch if you like."
