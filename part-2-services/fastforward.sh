#!/bin/bash
#
# Quick setup for the second part
# This script will simple copy all the instanafied files in the right places and execute the docker build process
# to enable the quick prep for the 2nd part of the Training

# The Ruby part
cd ../src/details
cp details-instana.rb details.rb
cp Dockerfile-instana Dockerfile

# Python
cd ../productpage
cp requirements-instana.txt requirements.txt
cp Dockerfile-instana Dockerfile

# node.js

cd ../ratings
cp package-instana.json package.json
cp ratings-instana.js ratings.js

# build containers

cd ..
./build-service.sh

# update docker-compose file
cd ..
cp docker-compose-instana.yaml docker-compose.yaml

# start up everything

docker-compose up -d

echo "Done setting up the environment. Have fun configuring the services."
