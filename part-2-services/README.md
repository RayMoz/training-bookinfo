# training-bookinfo - Custom service setup and application perspectives
How to customize the Instana experience

## The setup (the same as for the 1st part)

Make sure docker is installed. Find the docs and the convenience script here: https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script
Check that you are in the right section for your Linux distro of choice.

Also install `docker-compose`

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

# Quick Setup
If you already completed the first part but deleted the environment and need to start from scratch there is a script which will do all the prepwork for you in an instant.
Simply excute the following command in the directory you are in :-)

```bash
cd part-2-services
./fastforward.sh {yourimagename}
```
And you are done. This script will copy all the changes from the basic setup to the instanafied version in one go.
Use the *docker ps* command to check if everything is up and running.

### Run the agent
Install the Instana agent as before (part 1) via the docker installation with your own zone. This makes it much easier to configure the next step.

### Create your own Application Perspective in the sandbox
Once everything is up and running let's set up an application perspective using the UI.
Go to the *Applications* section in the Instana UI and add an application perspective. Use the *Agent zone* tag and pick your own agent zone. Give it a nice name and click save.
Now you will see data once there is some action so go ahead and request some bookinfo in your instance.

### Preparing the services
You will see all the services as they are coming to life in Instana.
Those are named after the containers and in our case are self explaining. But what if your container is just named *container* or *php* or *python*? How to distinguish them then and also how to filter?
This is a job for Application Perspectives (for filtering) and for some customization to give us more meaningful servicenames.

### node.js app name
From Unknown to your distinguished name in the stack.
The name of the node.js app is *Unkown* when we look at the infrastructure stack info. That is because there is no name set in the package.json file.
We can change that and give the node app a name via:
```json
{
  "name": "{my-name} Ratings",
  "version": "1.0.0",
  "description": "ratings REST API",
  "scripts": {
    "start": "node ratings.js"
  }
}
```
The Instana sensor will read those and apply them.
Let's do that an simply add those 3 attributes (name, version, description) to the package.json file.
The rebuild the container and run docker-compose again just like the first times.

```bash
docker build -t {yourname}/examples-bookinfo-ratings-v2:latest -t {yourname}/examples-bookinfo-ratings-v2:1.1.0
cd ../..
docker-compose up -d
```
Et voilá the node.js app now has a name in the infrastructure stack.
And we can use it for filtering.

### Servicename via custom rule
As we have a node.ja App name now we can we use a custom rule to redefine the service name.
Let's do this and see what side-effect we get with this approach.

### Service Name via env Variable
If you want to name a service in a distinct way for a specific process the ENV Variable is the way to go.
This documentation provides you an overview:  [Servicename via Variable](https://www.ibm.com/docs/en/obi/current?topic=applications-services#specify-the-instanaservicename-environment-variable "Instana Documentation")

Let's do this for the Python service productpage.
We need to add the env variable to the Dockerfile and rebuild the container as the process needs to be restarted to pick up the variable.
There is a prepared Dockerfile (Dockerfile-instana) which you can copy to Dockerfile and uncomment the line with the ENV variable. Replace {yourname} with your name and rebuild the container (like before).

### Let's build an application perspective automatically via REST
Creating an AP is easy in the UI and I think pretty intuitive.
For development purposes e.g. canary builds you may want to create them automatically while deploying new releases.
You can use the REST API for that.
***Be careful though ***
After you are done please delete the AP again otherwise it will sit there forever but not getting any data and just block the view.
You can find the complete REST API documentation here: https://instana.github.io/openapi/#operation/getApplicationConfigs

```bash
# REST API example - please mind the API token. It is redacted here for security purposes.
curl --request POST \
--url https://training-techsandbox.instana.io/api/application-monitoring/settings/application \
--header 'authorization: apiToken {the-API-token}' \
--header 'content-type: application/json' \
--data '{
  "label" : "{yourname} REST Example",
  "matchSpecification" : null,
  "tagFilterExpression" : {
    "type" : "TAG_FILTER",
    "name" : "docker.image.name",
    "stringValue" : "",
    "numberValue" : null,
    "booleanValue" : null,
    "key" : null,
    "value" : "{yourcontainerimagename}",
    "operator" : "STARTS_WITH",
    "entity" : "DESTINATION"
  },
  "scope" : "INCLUDE_IMMEDIATE_DOWNSTREAM_DATABASE_AND_MESSAGING",
  "boundaryScope" : "INBOUND",
  "accessRules" : [ {
    "accessType" : "READ_WRITE",
    "relationType" : "GLOBAL",
    "relatedId" : null
  } ]
}'

```

And now for the hints to make this easy.
## How to get the API query easily
The fastest way to get the API query JSON object is to use the Unbounded Analytics view in Instana.
Use filter and group to create the view / constraints you like to have. Then use the "API Query" button on the right side.
That's it. You can simply copy the filter tags and use them in the REST Call.

## How to get a AP definition easily
Simply retrieve the existings AP via REST. It is a single line:

```bash
curl -H "Authorization: apiToken {the-API-token}" "https://training-techsandbox.instana.io/api/application-monitoring/settings/application?pretty"
```
