# training-bookinfo
A small µ-service based demo app

# Bookinfo Training Setup
Originally used to demo and test Istio service meshes, the bookinfo app is ideal to train Instana agent setup.
It is a nice microservice app which uses Java, Ruby, Python, node.js, MongoDB and MySQL.

It is meant to serve as an example for servicemeshing with Istio, but you can run it also just with a plain docker / docker-compose setup.
The later is ideal to create a situation that we have usually at customers. A relative easy docker agent installation but we have some holes likes node.js instrumentation, Python instrumentation, Ruby as well and MySQL asking for credentials.

## The setup

Make sure docker is installed
also install `docker-compose`
```yaml
apt install docker-compose
```

Clone the repo

```yaml
git clone [https://github.com/RayMoz/training-bookinfo.git](https://github.com/RayMoz/training-bookinfo.git)
```

Go to the bookinfo sample

```yaml
cd training-bookinfo
```

### Run the build-services script with a repo name and a version tag

```yaml
cd src
./build-services.sh 1.0 stan
```

This will create all the necessary docker images

### Adjust the .env file
Change the repo to the name you picked during the build process, e.g. *stan*

```yaml
cd ..
vi .env
```
### Start up the app
The docker-compose.yaml is ready to start. When using docker-compose it will read the .env file automatically using the correct images.

```yaml
version: '3'
services:
  productpage:
    image: ${REPO}/examples-bookinfo-productpage-v1:latest
    networks:
      - bookinfo-network
    healthcheck:
      test: [ "CMD", "curl", "-H", "X-INSTANA-SYNTHETIC: 1", "-f", "http://localhost:9080/health" ]
      interval: 1s
      timeout: 10s
      retries: 3
    logging: &logging
      driver: "json-file"
      options:
        max-size: "25m"
        max-file: "2"
    ports:
      - "9080:9080"
  mysqldb:
    image: ${REPO}/examples-bookinfo-mysqldb:latest
    cap_add:
      - NET_ADMIN
    networks:
      - bookinfo-network
    environment:
      MYSQL_ROOT_PASSWORD: password
    logging:
      <<: *logging
  ratings:
    image: ${REPO}/examples-bookinfo-ratings-v2:latest
    environment:
      SERVICE_VERSION: v2
      DB_TYPE: mysql
      MYSQL_DB_HOST: mysqldb
      MYSQL_DB_PORT: 3306
      MYSQL_DB_USER: root
      MYSQL_DB_PASSWORD: password
      HOST_IP: 172.19.0.1
    depends_on:
      - mysqldb
    networks:
      - bookinfo-network
    healthcheck:
      test: [ "CMD", "curl", "-H", "X-INSTANA-SYNTHETIC: 1", "-f", "http://localhost:9080/health" ]
      interval: 1s
      timeout: 10s
      retries: 3
    logging:
      <<: *logging
  reviews:
    image: ${REPO}/examples-bookinfo-reviews-v3:latest
    networks:
      - bookinfo-network
    healthcheck:
      test: [ "CMD", "curl", "-H", "X-INSTANA-SYNTHETIC: 1", "-f", "http://localhost:9080/health" ]
      interval: 1s
      timeout: 10s
      retries: 3
    logging:
      <<: *logging
  details:
    image: ${REPO}/examples-bookinfo-details-v1:latest
    networks:
      - bookinfo-network
    healthcheck:
      test: [ "CMD", "curl", "-H", "X-INSTANA-SYNTHETIC: 1", "-f", "http://localhost:9080/health" ]
      interval: 1s
      timeout: 10s
      retries: 3
    logging:
      <<: *logging

networks:
  bookinfo-network:
```

Now you can fire up the app with

```yaml
docker-compose up
//or
docker-compose up -d
// this will bring the prompt back and run the system detached from the terminal
```

You can reach the system now with **http://{hostname}:9080**

### Install Instana agent as docker container

Just use the docker run command from the Instana instance “deploy agents” wizard

### What do we see once the agent is running:

Host info works fine, containers are discovered, Java app starts reporting nicely (WebSphere Liberty), but we miss info for:

- node.js app
- Python app
- Ruby app
- MySQL

The UI gives us already links to the troubleshooting section what we need to do

So we need to do some adjusting

### node.js

Here we need to add the instrumentation to the code (one line) and add the package to the package.json file:

```yaml
{
  "scripts": {
    "start": "node ratings.js"
  },
  "dependencies": {
    "httpdispatcher": "1.0.0",
    "mongodb": "^3.6.0",
    "mysql": "^2.15.0",
    "@instana/collector": "1.139.0"
  }
}
```

```yaml
require('@instana/collector')();

var http = require('http')
var dispatcher = require('httpdispatcher')
```

rebuild docker container - run

**Still not seeing any data: Let’s check the logs of the app (docker logs {container ID})**

Problem is that the sensor can not reach the agent due to IP conflict.

Reason: the HOST_IP is changed in the docker-compose.yaml file and we need to add the default IP in order for the sensor to be able to announce itself in the agent.

```yaml
ratings:
    image: ${REPO}/examples-bookinfo-ratings-v2:latest
    environment:
      SERVICE_VERSION: v2
      DB_TYPE: mysql
      MYSQL_DB_HOST: mysqldb
      MYSQL_DB_PORT: 3306
      MYSQL_DB_USER: root
      MYSQL_DB_PASSWORD: password
      HOST_IP: 172.19.0.1
      INSTANA_AGENT_HOST: 172.17.0.1
      # Default host IP for Linux docker distributions
    depends_on:
      - mysqldb
    networks:
      - bookinfo-network
    healthcheck:
      test: [ "CMD", "curl", "-H", "X-INSTANA-SYNTHETIC: 1", "-f", "http://localhost:9080/health" ]
      interval: 1s
      timeout: 10s
      retries: 3
    logging:
      <<: *logging
```

Add the INSTANA_AGENT_HOST ENV to the docker-compose.yaml for the ratings service

172.17.0.1 is the default Docker host IP which we use here and it works

### Python app

Here we have a conflict with the already existing opentracing and jaeger client dependencies. Installing the pip won’t work as Instana needs a more recent opentracing lib while the jaeger client needs an older one.

Solution:
Remove the opentracing instrumentation and clear the jaeger-client dependency, also remove gevent and greenlet (not used at all) from the requirements.txt

Do not run the test in the Dockerfile as it expects the opentracing instrumentation.

Without Jaeger and the dependencies on old packages the auto instrumentation works though we don’t see any traces yet.

### Ruby app

Problem here is that the container is using a slim Ruby runtime which can not install the Instana gem.

Solution: Rebuild container with a full Ruby runtime by changing the image in the Dockerfile

```docker
FROM ruby:2.7.1-slim
# change to
FROM ruby:2.7

# add after the WORKDIR directive
RUN gem install instana
```

Add require statement to details.rb

```ruby
require 'webrick'
require 'json'
require 'net/http'
require 'instana' # new to include the tracing
```

Now rebuild the container
