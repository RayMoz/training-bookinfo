# training-bookinfo
A small µ-service based demo app

# Bookinfo Training Setup
Originally used to demo and test Istio service meshes, the bookinfo app is ideal to train Instana agent setup.
It is a nice microservice app which uses Java, Ruby, Python, node.js, MongoDB and MySQL.

It is meant to serve as an example for servicemeshing with Istio, but you can run it also just with a plain docker / docker-compose setup.
The later is ideal to create a situation that we have usually at customers. A relative easy docker agent installation but we have some holes likes node.js instrumentation, Python instrumentation, Ruby as well and MySQL asking for credentials.

When you follow it step by step you'll be facing situations which are typical for an initial agent deployment of Instana; e.g. a MySQL DB which needs extra credentials or a node.js process which needs attention before it is fully traced.

## The setup

Make sure docker is installed
also install `docker-compose`
```yaml
apt install docker-compose
```

Clone the repo

```yaml
git clone https://github.com/RayMoz/training-bookinfo.git
```

Go to the bookinfo sample

```yaml
cd training-bookinfo
```

### Run the build-services script with a repo name and a version tag

```yaml
cd src
./build-services.sh 1.0 {your-name}
```

This will create all the necessary docker images and store them locally.

### Adjust the .env file
Change the repo to the name you picked during the build process, e.g. *your-name*.
This is important to actually match the image names in the docker-compose file with the names of the images you just created.

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

You can reach the bookinfo app now with **http://{hostname}:9080**

### Install Instana agent as docker container

Just use the docker run command from the Instana instance “deploy agents” wizard
When you use a personal ZONE attribute (just enter it in the field in the wizard) it makes it easier for you to find your machine in the Instana UI.

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

rebuild docker container - and restart the app with docker-compose.

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

Todo: Check if autotrace works when opentracing is not yet part of the requirements.txt

Here we have a conflict with the already existing opentracing and jaeger client dependencies. Installing the pip won’t work as Instana needs a more recent opentracing lib while the jaeger client needs an older one.

Solution:
Remove the opentracing instrumentation and clear the jaeger-client dependency, also remove gevent and greenlet (not used at all) from the requirements.txt

Do not run the test in the Dockerfile as it expects the opentracing instrumentation.

Without Jaeger and the dependencies on old packages the auto instrumentation works though we don’t see any traces yet.

### Ruby app

Ruby needs an Instana gem to be installed for the full tracing capability. 2 Changes are required.
1. Add the gem to the runtime by adding the RUN command in the Dockerfile
2. Add the require statement to the Ruby file (in this case details.rb)

```docker
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
After applying those changes you need to rebuild container and start it again. Give it a new version tag (e.g. 1.0.1) and also a latest tag.

### MySQL - credentials missing

The problem with the MySQL monitoring is in our case, that it is not using the standard root login but has actually a password assigned.
No problem, we can configure the agent with the MySQL credentials in the *configuration.yaml* file.
But, wait a second, the agent is running in a container. How can I edit the file? We actually can not edit the standard configuration.yaml.
But we can copy a configuration file via `docker cp` to the running container.
Or use a volume mount during container startup, but that requires a complete container restart.
Here is the content of the file, let's call it *configuration-mysql.yaml*

```yaml
# Mysql
com.instana.plugin.mysql:
  user: 'root'
  password: 'password'
```
Now let's use the `docker cp`
```bash
docker cp configuration-mysql.yaml {container-id}:/opt/instana/agent/etc/instana/configuration-mysql.yaml
```
That's it.
Look for this line in the agent.log: `Parsed configuration file /opt/instana/agent/etc/instana/configuration-mysql.yaml`
The file is hot-read and the credentials are applied immediately.

You can also mount the file into the filesystem of the container during container startup.
The container needs to be completely restarted though which can be timeconsuming.

```bash
--volume {your-local-path}/configuration-mysql.yaml:/opt/instana/agent/etc/instana/configuration-mysql.yaml
```
### WebSphere Liberty application server
This one is automatically found and instrumented at runtime. Though it uses a IBM J9 JVM which usually needs an extra configuration to enable tracing.
Here is an excerpt of the documentation that explains why this works out of the box:

> Optional: Configure the ws-javaagent.jar file with the -javaagent JVM option. The ws-javaagent.jar file is in the ${wlp.install.dir}/bin/tools directory of the Liberty installation. You are advised to configure the ws-javaagent.jar file, but it is not mandatory unless you use capabilities of the server that require it, such as monitoring or trace. If you contact IBM® support, you might need to provide trace, and if so, you must start the server with the ws-javaagent.jar file, even if you do not normally use it.

https://www.ibm.com/docs/en/was-liberty/base?topic=liberty-embedding-server-in-your-applications
