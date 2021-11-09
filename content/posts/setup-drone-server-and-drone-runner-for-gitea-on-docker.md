---
title: "Setup Drone Server and Docker Runner for Gitea"
date: 2021-11-09T22:00:00+02:00
draft: false
description: "Tutorial on setting up a self-hosted ci service with drone server and drone runner with gitea on docker and docker-compose, a open-source alternative to Github Actions and Gitlab CI."
tags: ["docker", "gitea", "drone", "cicd"]
categories: ["containers"]
---

Drone, a continiuous integration platform which is super close to my heart :heart: ! 

In this post we will setup Drone Server and Drone Runner for Gitea to run your Continuous Integration Pipelines, then we will setup a example pipeline, discover the drone-cli and how to extend our setup with more runners.

## What is Drone?

**[Drone](https://www.drone.io/)** is a self-service continuous delivery platform which is built on container technology and can be used for CI/CD Pipelines, and has one extensive list of [plugins](http://plugins.drone.io/) enabling you to run almost any workflow you can think of.

With configuration as code, pipelines are configured with a simple, easy‑to‑read file that you commit to your git repository such as GitHub, Gitlab, Gogs, Gitea, Bitbucket and for this tutorial we will be focusing on Gitea.

Each Pipeline step is executed inside an isolated docker container that is automatically downloaded at runtime, if not found in cache. 

Beautiful pipeline syntax:

```yaml
---
kind: pipeline
type: docker
name: hello-world

steps:
  - name: say-hello
    image: busybox
    commands:
      - echo hello-world
``` 

## What are we doing today

In a previous post we've setup gitea for version control and in this tutorial we will be setting up a drone server with ssl termination using traefik and letsencrypt, and a drone runner which will be responsible for running the jobs. 

Then we will create a oauth application so that we can integrate drone with gitea, so that we can trigger our pipelines when we commit to gitea.

A note taken from [readme.drone.io](https://readme.drone.io/server/provider/gitea/)

> Please note we strongly recommend installing Drone on a dedicated instance. We do not recommend installing Drone and Gitea on the same machine due to network complications, and we definitely do not recommend installing Drone and Gitea on the same machine using docker-compose. 

For this example we will be running drone-server and drone-runner on the same instance for demonstration purposes on docker-compose, and Gitea running on a separate instance.

## Assumptions

I will assume that you have **[docker](https://docs.docker.com/get-docker/)** and **[docker-compose](https://docs.docker.com/compose/install/)** installed. If you are following this guide to run Drone with Gitea, you can look at my tutorial on setting up **[Gitea on Docker with Traefik](https://containers.fan/posts/setup-gitea-on-docker-with-traefik/)**

If you need more info on [Traefik](https://traefik.io/) you can have a look at their website, but I have also written a post on [setting up Traefik v2](https://containers.fan/posts/setup-traefik-v2-docker-compose/) in detail, but we will touch on that in this post.

## Drone Components

Before diving into the setup of Drone, we will give a small overview of components and terminology:

- **Drone Server**: Responsible for hosting the UI, storing the encrypted secrets, hosts the API, etc.
- **Drone Runner**: The component that will run your actual builds. There's [multiple runners](https://readme.drone.io/runner/overview/) that drone offers, but for this case we will focus on the docker runner.

## Environment Details

I have 2 DNS entries pointing to 2 different instances:

- Gitea: `git.rbkr.xyz` (gitea node: 192.168.0.10) - [setup from this post](https://containers.fan/posts/setup-traefik-v2-docker-compose/)
- Drone: `ci.rbkr.xyz` (this node: 192.168.0.12) - this post
- Drone Docker Runner: (this node: 192.168.0.12) - this post

Accessing our Drone Server will be done over `HTTPS` on port `443`.

## Create Oauth Application 

We need to create a oauth application in Gitea in order for us to authenticate with our Gitea credentials in Drone.

Head over to your profile and select settings:

![image](https://user-images.githubusercontent.com/567298/139193816-a8011a00-aeb1-443e-afc3-16bdbb551ee8.png)

Select the "Applications" tab and you should see the following:

![image](https://user-images.githubusercontent.com/567298/139193884-bd9e2b95-6680-427a-8074-338934fd826d.png)

Create a new Oauth2 application for drone and set the redirect uri to your drone's url

![image](https://user-images.githubusercontent.com/567298/139196272-c27f2848-6008-49ac-b954-b2bc80c1660f.png)

And select "Create application":

You will get a client id and client secret:

![image](https://user-images.githubusercontent.com/567298/139196347-276e9997-347a-431c-a2c5-b04f4805bc21.png)

Then save the results in your `.env` on your drone project directory, which we will create:

```
mkdir drone
cd drone
```

Since we are in the drone project directory, save the `.env` file with the following content (yours will differ):

```
DRONE_GITEA_CLIENT_ID=a46018de-3bd4-4e6c-86d6-825da0cb65c0
DRONE_GITEA_CLIENT_SECRET=tSjxsV9_wTzdYl33iLIStvyvNmnll5MsTA134zzGzKk=
```

Once you saved the content, we need to write the `docker-compose.yml` for drone-server and our drone-runner. You want to split your server and runners from each other, but since this is just a demonstration, we will keep them on the same docker host:

```yaml
---
version: '3.8'

services:
  drone-traefik:
    image: traefik:2.4
    container_name: drone-traefik
    restart: unless-stopped
    volumes:
      - ./traefik/acme.json:/acme.json
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - public
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.api.rule=Host(`traefik.rbkr.xyz`)'
      - 'traefik.http.routers.api.entrypoints=https'
      - 'traefik.http.routers.api.service=api@internal'
      - 'traefik.http.routers.api.tls=true'
      - 'traefik.http.routers.api.tls.certresolver=letsencrypt'
    ports:
      - 80:80
      - 443:443
    command:
      - '--api'
      - '--providers.docker=true'
      - '--providers.docker.exposedByDefault=false'
      - '--entrypoints.http=true'
      - '--entrypoints.http.address=:80'
      - '--entrypoints.http.http.redirections.entrypoint.to=https'
      - '--entrypoints.http.http.redirections.entrypoint.scheme=https'
      - '--entrypoints.https=true'
      - '--entrypoints.https.address=:443'
      - '--certificatesResolvers.letsencrypt.acme.email=me@example.com'
      - '--certificatesResolvers.letsencrypt.acme.storage=acme.json'
      - '--certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=http'
      - '--log=true'
      - '--log.level=INFO'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  drone-server:
    container_name: drone
    image: drone/drone:${DRONE_VERSION:-2.4}
    restart: unless-stopped
    depends_on:
      drone-traefik:
        condition: service_started
    environment:
      # https://docs.drone.io/server/provider/gitea/
      - DRONE_DATABASE_DRIVER=sqlite3
      - DRONE_DATABASE_DATASOURCE=/data/database.sqlite
      - DRONE_GITEA_SERVER=https://git.rbkr.xyz/
      - DRONE_GIT_ALWAYS_AUTH=false
      - DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
      - DRONE_SERVER_PROTO=https
      - DRONE_SERVER_HOST=ci.rbkr.xyz
      - DRONE_TLS_AUTOCERT=false
      - DRONE_USER_CREATE=${DRONE_USER_CREATE}
      - DRONE_GITEA_CLIENT_ID=${DRONE_GITEA_CLIENT_ID}
      - DRONE_GITEA_CLIENT_SECRET=${DRONE_GITEA_CLIENT_SECRET}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.drone.rule=Host(`ci.rbkr.xyz`)"
      - "traefik.http.routers.drone.entrypoints=https"
      - "traefik.http.routers.drone.tls.certresolver=letsencrypt"
      - "traefik.http.routers.drone.service=drone-service"
      - "traefik.http.services.drone-service.loadbalancer.server.port=80"
    networks:
      - public
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./drone:/data

  drone-runner:
    container_name: drone-runner
    image: drone/drone-runner-docker:${DRONE_RUNNER_VERSION:-1}
    restart: unless-stopped
    depends_on:
      drone:
        condition: service_started
    environment:
      # https://docs.drone.io/runner/docker/installation/linux/
      # https://docs.drone.io/server/metrics/
      - DRONE_RPC_PROTO=https
      - DRONE_RPC_HOST=ci.rbkr.xyz
      - DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
      - DRONE_RUNNER_NAME="${HOSTNAME}-runner"
      - DRONE_RUNNER_CAPACITY=2
      - DRONE_RUNNER_NETWORKS=public
      - DRONE_DEBUG=false
      - DRONE_TRACE=false
    networks:
      - public
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

networks:
  public:
    name: public
```

In the `docker-compose.yml` we have the following key items that we should highlight:

**Traefik**:

- `traefik.http.routers.api.rule=Host()` - the host header we will use to access Traefik's dashboard
- `80:80, 443:443`  - exposing port 80 and 443 on the host
- `--certificatesResolvers.letsencrypt.acme.email` - the email address for communication from LetsEncrypt

**Drone Server**:

- [`DRONE_GITEA_SERVER`](https://docs.drone.io/server/reference/drone-gitea-server/) - the git server url [from my previous post](https://containers.fan/posts/setup-gitea-on-docker-with-traefik/)
- [`DRONE_RPC_SECRET`](https://docs.drone.io/server/reference/drone-rpc-secret/) - the shared secret used to authenticate the rpc connection to the server, which we saved to the `.env` file.
- [`DRONE_SERVER_PROTO`](https://docs.drone.io/server/reference/drone-server-proto/) - set to https in my case as I am using Traefik for ssl termination
- [`DRONE_SERVER_HOST`](https://docs.drone.io/server/reference/drone-server-host/) - the hostname of my gitea server 
- [`DRONE_TLS_AUTOCERT`](https://docs.drone.io/server/reference/drone-tls-autocert/) - I have set this to false, as I am using Traefik, if you want to make use of LetsEncrypt set this to true
- [`DRONE_USER_CREATE`](https://docs.drone.io/server/reference/drone-user-create/) - we are using this to auto provision our system admin account.
- [`DRONE_GITEA_CLIENT_ID`](https://docs.drone.io/server/reference/drone-gitea-client-id/) - this is the gitea oauth client id that we created earlier and the value is saved in our `.env` file.
- [`DRONE_GITEA_CLIENT_SECRET`](https://docs.drone.io/server/reference/drone-gitea-client-secret/) - his is the gitea oauth client secret that we created earlier and the value is saved in our `.env` file.
- `traefik.http.routers.drone.rule=Host()` - the hostname we will route requests to the drone server, in my case ci.rbkr.xyz. 

**[Drone Docker Runner](https://readme.drone.io/runner/docker/overview/)**

- [`DRONE_RPC_PROTO`](https://readme.drone.io/runner/kubernetes/configuration/reference/drone-rpc-proto/) - the protocol we use to communicate with the drone server, I used https.
- [`DRONE_RPC_HOST`](https://readme.drone.io/runner/exec/configuration/reference/drone-rpc-host/) - this is the drone server which we will communicate to, in my case ci.rbkr.xyz.
- [`DRONE_RPC_SECRET`](https://docs.drone.io/server/reference/drone-rpc-secret/) - the shared secret used to authenticate the rpc connection to the server, which we saved to the `.env` file.
- [`DRONE_RUNNER_NAME`](https://docs.drone.io/runner/macstadium/configuration/reference/drone-runner-name/) - the name of our runner, useful for identifying runners when you have multiple runners.
- [`DRONE_RUNNER_CAPACITY`](https://readme.drone.io/runner/exec/configuration/reference/drone-runner-capacity/) - the number of concurrent pipelines that a runner can execute.
- [`DRONE_RUNNER_NETWORKS`](https://readme.drone.io/runner/nomad/configuration/reference/drone-runner-networks/) - the list of docker networks thats attached to the pipeline steps. 

And since we require a couple more environment variables, we can generate a `DRONE_RPC_SECRET` with `openssl`:

```
openssl rand -hex 24
faa1ce4fd08e481bb737548ac7569c202fa7001928056028
```

And then we can update our `.env`:

```
HOSTNAME=ip-172-31-16-4
GITEA_ADMIN_USER=ruanbekker
DRONE_RPC_SECRET=faa1ce4fd08e481bb737548ac7569c202fa7001928056028
DRONE_GITEA_CLIENT_ID=a46018de-3bd4-4e6c-86d6-825da0cb65c0
DRONE_GITEA_CLIENT_SECRET=tSjxsV9_wTzdYl33iLIStvyvNmnll5MsTA134zzGzKk=
DRONE_USER_CREATE="username:${GITEA_ADMIN_USER},machine:false,admin:true,token:${DRONE_RPC_SECRET}"
```

Once we have our configuration up to date and saved as `docker-compose.yml`, create the traefik directory and set the permissions of our `acme.json`:

```
mkdir traefik
touch traefik/acme.json
chmod 600 traefik/acme.json
```

Now its time to start our containers:

```
docker-compose up -d
...
Creating drone-traefik ... done
Creating drone-server ... done
Creating drone-runner ... done
```

Once they are started, allow Traefik about a minute or so to sort out the LetsEncrypt certificates, and then head over to your Drone Server UI, in my case it's https://ci.rbkr.xyz and you should see a ui like this:

![image](https://user-images.githubusercontent.com/567298/139197419-d165d7a3-d95a-4e0f-8020-11876511a42e.png)

Select continue, as we are still logged into Gitea, it asks us to authorise this application:

![image](https://user-images.githubusercontent.com/567298/139197596-e0b82968-10e6-4ab3-a010-19a995cd572f.png)

Then continue with the registration:

![image](https://user-images.githubusercontent.com/567298/139197645-a937de7f-4202-4f4a-9aeb-d1c49a9c90f8.png)

Now you should see your repositories from git appearing in the dashboard (if you created any repositories that is)

![image](https://user-images.githubusercontent.com/567298/139197783-b853b58c-fb93-4fab-9e3e-a2fa8b5b6dec.png)

Lets head back to our hello-world repository:

![image](https://user-images.githubusercontent.com/567298/139197864-9b06fa3f-9653-45c9-8d69-d0b3201ddc3d.png)


If you don't have one you can create a repository, then commit this pipeline file in `.drone.yml`:

```yaml
---
kind: pipeline
type: docker
name: hello-world

trigger:
  event:
    - push

steps:
  - name: say-hello
    image: busybox
    commands:
      - echo hello-world
```

So then we should have a file like this in Gitea:

![image](https://user-images.githubusercontent.com/567298/139199479-2d7a37ad-3255-4d98-8066-49f63a9cfea2.png)

Now head back to Drone where all the repositories are listed:

![image](https://user-images.githubusercontent.com/567298/139198460-5efeaf96-6a08-4040-a0bb-83bc037fdf9a.png)

Then select the repository where you commited your `.drone.yml`, in my case its "ruanbekker/hello-world" and you should see that the repository is not active:

![image](https://user-images.githubusercontent.com/567298/139198580-28e0b0ea-ce78-401d-9ab2-4b518e7d2b74.png)

From the "Settings" tab, scroll down to the bottom and ensure that drone's configuration is set to `.drone.yml` and select "Save changes":

![image](https://user-images.githubusercontent.com/567298/139198851-838ee227-ceb5-445c-b4b7-3ae0322bdae1.png)

Head back to git, and commit a file, in my case it will be a file `trigger` just so that we can trigger the pipeline:

From Drone, when we look at our builds, we can see that our latest execution succeeded:

![image](https://user-images.githubusercontent.com/567298/139199668-093d19e8-7d5d-46e0-a15f-0ecc97fd48c4.png)

When we select our execution, from our log view we can see each step's output:

![image](https://user-images.githubusercontent.com/567298/139199768-cd37abac-5bc1-4904-b3a8-962ea5176419.png)

We can also see our steps from the graph view:

![image](https://user-images.githubusercontent.com/567298/139199893-cc728f5c-8323-4109-b5aa-a71dbf19698b.png)
 
For more examples, Drone has a repo called [drone_playground](https://github.com/drone/drone_playground/), which we can import into Gitea:

![image](https://user-images.githubusercontent.com/567298/139205745-37621e12-0a5c-4142-8d79-7dc84970e366.png)

Paste the Migrate / Clone URL `https://github.com/drone/drone_playground` and name your repository:

![image](https://user-images.githubusercontent.com/567298/139205970-0a008f1d-7dfb-4f1f-ac7d-dd901113ce8e.png)

Then select "Migrate Repository", and you should have a repository in your Gitea:

![image](https://user-images.githubusercontent.com/567298/139206203-2c732d27-b833-4471-9641-820c52c7c5cb.png)

Head back to drone's dashboard, select Sync to get the repository from Gitea, and you should see it in the list of repositories:

![image](https://user-images.githubusercontent.com/567298/139206391-ec39b14e-25f1-47f6-87ff-3045c8a9a480.png)

Select the repository, activate it and scroll to the bottom where you can provide the name of your `.drone.yml` and point it to `mysql/.drone.yml` as we want to use the mysql pipeline from Git, you can use any of the available pipelines, but I'm going with the mysql one:

![image](https://user-images.githubusercontent.com/567298/139206670-84182473-9f42-4d73-a524-05de285810d7.png)

So it will look like the following in the configuration section:

![image](https://user-images.githubusercontent.com/567298/139206956-aaaa8714-d5ab-492d-b41a-e5f281803a05.png)

Then select "save changes". Head back to Gitea and trigger the pipeline by pushing a commit to master or creating a new build via Drone, for this example I will be pushing a file `trigger` to master, then from Drone we should see that the pipeline was triggered:

![image](https://user-images.githubusercontent.com/567298/139207389-316a1162-b0cf-48a1-a87b-4eb8769d67b2.png)

If we select the execution, we can see that our pipeline ran successfully and from the steps we can see the following happened:

- clone: fetches the content from git
- mysql-server: starts up a mysql container
- mysql healthcheck: ensures that the mysql container started and using a mysql client to connect to mysql
- mysql-client DDL: creates a table in mysql and inserts data into mysql
- mysql-client DML: reads the data from the table that we created

![image](https://user-images.githubusercontent.com/567298/139207849-136e6bb4-70a0-4ba9-b3b8-45ee8ebbcdb7.png)

## Drone CLI

We can interact with Drone using their CLI, for installation documentation you can consult their docs:
- https://docs.drone.io/cli/install/

But in short for Mac, the installation steps look like this:

```
curl -L https://github.com/drone/drone-cli/releases/latest/download/drone_darwin_amd64.tar.gz | tar zx
sudo cp drone /usr/local/bin/drone
```

Verifying that the drone cli utility was installed:

```
drone --version
drone version 1.4.0
```

Now to configure drone cli, we need to get our personal access token by heading to our `/account` section, which for me is https://ci.rbkr.xyz/account

Which will look like the following:

![image](https://user-images.githubusercontent.com/567298/139209079-7dd9636d-d03f-421e-8879-0c49fd8bd9e6.png)

When we first try out the example api usage command they provide:

```
$ curl -i https://ci.rbkr.xyz/api/user -H "Authorization: Bearer faa1ce4fd08e481bb737548ac7569c202fa7001928056028"
HTTP/2 200
cache-control: no-cache, no-store, must-revalidate, private, max-age=0
content-type: application/json
date: Thu, 28 Oct 2021 07:38:51 GMT
expires: Thu, 01 Jan 1970 00:00:00 UTC
pragma: no-cache
vary: Origin
x-accel-expires: 0
content-length: 263

{"id":1,"login":"ruanbekker","email":"ruan@localhost.net","machine":false,"admin":true,"active":true,"avatar":"https://git.rbkr.xyz/user/avatar/ruanbekker/-1","syncing":false,"synced":1635405616,"created":1635401206,"updated":1635401206,"last_login":1635401572}
```

And when we try out the example cli usage, set the drone server and drone token to your environment:

```
$ export DRONE_SERVER=https://ci.rbkr.xyz
$ export DRONE_TOKEN=faa1ce4fd08e481bb737548ac7569c202fa7001928056028
```

A list of subcommands are available when running:

```bash
$ drone --help
NAME:
   drone - command line utility

USAGE:
   drone [global options] command [command options] [arguments...]

VERSION:
   1.4.0

COMMANDS:
     build      manage builds
     cron       manage cron jobs
     log        manage logs
     encrypt    encrypt a secret
     exec       execute a local build
     info       show information about the current user
     repo       manage repositories
     user       manage users
     secret     manage secrets
     server     manage servers
     queue      queue operations
     orgsecret  manage organization secrets
     autoscale  manage autoscaling
     convert    convert legacy format
     lint       lint the yaml file
     sign       sign the yaml file
     jsonnet    generate .drone.yml from jsonnet
     starlark   generate .drone.yml from starlark
     plugins    plugin helper functions
     template   manage templates
     help, h    Shows a list of commands or help for one command
```

Then list our repositories:

```
$ drone repo ls
ruanbekker/drone_playground
ruanbekker/hello-world
```

List our builds for a repository:

```
$ drone build ls ruanbekker/hello-world
Build #4
Status: success
Event: push
Commit: a219a2602a62b2ffaac429eefcd95627ac2c792b
Branch: master
Ref: refs/heads/master
Author: ruanbekker <ruan@localhost.net>
Message: Update '.drone.yml'
```

We can view the logs of our build, let's take the clone step as an example:

```
$ drone log view ruanbekker/hello-world 4 1 1
Initialized empty Git repository in /drone/src/.git/
+ git fetch origin +refs/heads/master:
From https://git.rbkr.xyz/ruanbekker/hello-world
 * branch            master     -> FETCH_HEAD
 * [new branch]      master     -> origin/master
+ git checkout a219a2602a62b2ffaac429eefcd95627ac2c792b -b master
Already on 'master'
```

The nice thing that I really like about drone is to exec local builds using the cli. First clone your repo:

```
git clone https://git.rbkr.xyz/ruanbekker/hello-world
```

Change into the repo directory:

```
cd hello-world
```

Then execute a local build:

```
$ drone exec
[say-hello:0] + echo hello-world
[say-hello:1] hello-world
```

Add a secret to our repo:

```
drone secret add --name dummysecret --data dummyvalue ruanbekker/hello-world
```

List our secrets:

```
$ drone secret ls ruanbekker/hello-world
dummysecret
Pull Request Read:  false
Pull Request Write: false
```

Then update your pipeline step to:

```
...
steps:
  - name: say-hello
    image: busybox
    environment:
      DUMMYSECRET:
        from_secret: dummysecret
    commands:
      - if [ "$${DUMMYSECRET}" == "dummyvalue" ] ; then echo true; else echo false; fi
```

And when we commit it to git, we can see that we evaluated the value from the secret (as a basic example that the secret was published to drone):

![image](https://user-images.githubusercontent.com/567298/139227016-d6172703-1a8e-4cd6-b1e6-debe1ddf7f37.png)

## Extending our Setup

If its a case where we want to run more nodes, with more runnes, we can implement the following `docker-compose.yml` for a extra runner:

```yaml
---
version: '3.8'

services:
  drone-runner:
    container_name: drone-runner
    image: drone/drone-runner-docker:${DRONE_RUNNER_VERSION:-1}
    restart: unless-stopped
    environment:
      - DRONE_RPC_PROTO=https
      - DRONE_RPC_HOST=ci.rbkr.xyz
      - DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
      - DRONE_RUNNER_NAME="${HOSTNAME}-runner"
      - DRONE_RUNNER_CAPACITY=2
      - DRONE_RUNNER_NETWORKS=public
      - DRONE_DEBUG=false
      - DRONE_TRACE=false
    networks:
      - public
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

networks:
  public:
    name: public
```

Just remember to populate your environment variables with your own configuration. 

We only demonstrated the docker runner, but have a look at their documentation as they have multiple runners available:
- https://docs.drone.io/runner/overview/

It's really easy extending your setup with drone plugins, this is also where drone shines, look at their extensive list of plugins:
- http://plugins.drone.io/

## Drone Announcements

There's been a lot of changes recently at Drone, so I will try and keep this tutorial up to date, but things might change dependending when you read this. 

For Drone announcements view:
- https://blog.drone.io/tags/announcements/

For Drone documentation view:
- https://readme.drone.io/

## Thank You

I hope this was helpful, I was really impressed with Glitchtip. If you liked this content, please make sure to share or come say hi on my website or twitter:

  * **Website**: [ruan.dev](https://ruan.dev)
  * **Twitter**: [@ruanbekker](https://twitter.com/ruanbekker)

