# training-bookinfo
This repository was branched to accompany courses from the Observability Heroes community (https://observability.mn.co). It provides a small µ-service based demo app to be installed and configured for observability with OpenTelemetry (OTel).

# Bookinfo Training Setup
Originally used to demo and test Istio service meshes, the bookinfo app is ideal to learn OTel agent setup and basic troubleshooting.
It is a nice microservice app which uses Java, Ruby, Python, node.js and MySQL.

It is meant to serve as an example for servicemeshing with Istio, but you can run it also just with a plain docker / docker-compose setup.
The latter is ideal to create a situation that allows us to practice the setup of OTel agents for different languages. Java, Python and node.js are autoinstrumented and Ruby is supported though needs a code change to work.

When you follow it step by step you'll be facing situations which are typical for an initial deployment of OpenTelemtry; e.g. your apps need to be setup correctly with a env variable more, a MySQL DB (can we monitor that at all with OTel?) which needs extra credentials or a Ruby app which needs attention before it is fully traced.

## Machine

Any Linux box with 2 CPU cores, 4 GB RAM, about 20 GB disk and a decent network connection will do nicely. For example t3 medium box in AWS EC2. You can also easily use a local VM running on your workstation (remember to setup Internet connectivity).

The `yum install` commands that you see throughout hints that this was developed on an RedHat/Amazon Linux system.

I run it also on myl Mac using Docker desktop, which works nicely.

## The setup

Make sure docker and docker-compose are installed.

```bash
sudo yum install docker

sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

sudo systemctl start docker
```
And the same for **git**

```bash
yum install git
```

Now clone the "otel" branch of the repo training-bookinfo repo
```bash
git clone -b otel https://github.com/RayMoz/training-bookinfo
```
Go to the bookinfo sample

```bash
cd training-bookinfo
```

### Run the build-services script with a repo name and a version tag

```bash
cd src
./build-services.sh 1.0 {your-name}
```

This will create all the necessary docker images and store them locally.

### Adjust the .env file
Change the repo to the name you picked during the build process, e.g. *your-name*.
This is important to actually match the image names in the docker-compose file with the names of the images you just created.

```bash
cd ..
vi .env
```
### Start up the app
The docker-compose.yaml is ready to start. When using docker-compose it will read the .env file automatically using the correct images.

Now you can fire up the app with

```bash
docker-compose up
```
or in detached mode to get back to the prompt

```bash
docker-compose up -d
```

You can reach the bookinfo app now with **http://{hostname}:9080**

### Check the OTel collector on your machine

As this is the last part of the Easy Entry course where we already setup a backend for our OTel collector which reads a logfile and gathers hostmetrics we only need to make sure it is up and running. Or set it up on the this machine as well. Follow the instructions in the community course to do so.
We are now going to pump the traces from our application into it. The only thing we need to add to the collector config is the opensearch as a exporter for traces in the pipeline:

```yaml
  pipelines:

    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug, otlp, opensearch]
```

### Let's start with Java - Reviews app

Java is autoinstrumented, which means we only need to add the javaagent.jar to the java commandline - and add some ENV variables to define the collector endpoint and the servicename, etc. We add this all in the docker-compose file, hence no code to change, no container image to rebuild.
https://opentelemetry.io/docs/zero-code/java/

What we need to do here is to download the javaagent.jar from the OTel downloadpage (see the Zero-code Java doc), copy it into the docker container image and then add it to the jvm.options file that our application server (WebSphere Liberty) uses.
We do both during the docker-compose start, hence nothing to do in the docker image. 

You can use the opentelemetry-javaagent.jar which is in this Git repo, but ideally you download the latest version and replace the one already sitting there. 

The only important change you need to make is to replace the paths in the docker-compose file, which mount the jvm.options file and the jar to the container. 
Due to a limitation in the docker-compose structure the paths have to be absolute and can not be shortcutted. The container simply will not start if you do it any other way - that means you have to replace that path in the docker-compose file that you see here, with the paths on your installation. 
```yaml
    volumes:
      - /home/someone/training-bookinfo/src/reviews/otel/jvm.options:/opt/ibm/wlp/usr/servers/defaultServer/jvm.options
      - /home/someone/GitHub/training-bookinfo/src/reviews/otel/opentelemetry-javaagent.jar:/opt/ibm/wlp/usr/shared/apps/opentelemetry-javaagent.jar
```
Great. That's it for Java.

### Python app - Productpage

Python is also auto instrumented. It would not need a code change or config change, but we are using Flask and there is an issue with the debug mode as this reloads the app and that will strip the autoinstrumentation. When debug is set to "true", the OTel instrumentation will not work. If you need the debug mode, then you need to disable the reloader like in this code snippet (last lines of the productpage.py)

```python
if __name__ == "__main__":
    app.run(port=9080, debug=True, use_reloader=False)
```

We set this in the productpage.py and we are done. When we build the OTel version together with the other apps with a script and restart with docker-compose

Hint: Do not run the test in the Dockerfile as it expects the opentracing instrumentation.

### node.js app - Ratings

node.js is also auto instrumented, which means it is very low effort to get the agent running.
Autoinstrumentation works nicely. Just needed to add the following lines to the dockerfile:
We need the OpenTelemetry API and the auto-instrumentation package for node.

The following additions need to be made in the dockerfile for the ratings app. 
```bash
cd ratings
vi Dockerfile
```
Add the following lines just after the initial RUN npm install
```Dockerfile
RUN npm install --save @opentelemetry/api
RUN npm install --save @opentelemetry/auto-instrumentations-node
```
And then add the following ENV variables to the docker-compose.yaml to the ratings service
```yaml
      OTEL_TRACES_EXPORTER: "otlp"
      OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4318"
      OTEL_NODE_RESOURCE_DETECTORS: "env,host,os"
      OTEL_SERVICE_NAME: "ratings"
      NODE_OPTIONS: "--require @opentelemetry/auto-instrumentations-node/register"
```
Needed to use port 4318 with HTTP, as the GRPC port 4317 didn't work and resulted in HTTP connection errors.
No need to change the ratings.js file though :-)

### Ruby app - Details

Ruby has no Zero-code instrumentation, which means we need to add it manually in the code. Our app is a standard REST service based on the Sinatra framework. It is supported and it is easy to trace it with OpenTelemetry.

TODO: Gemfile
TODO: RUN directives

Finishing touches missing, coming in the next 24 hours - You can check out for yourself how the Ruby stuff works. It is already in the Dockerfiles, etc. Onyl the description here is missing.




