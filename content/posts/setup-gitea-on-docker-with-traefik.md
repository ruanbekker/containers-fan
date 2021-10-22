---
title: "Setup a Self-Hosted Git Service with Gitea"
date: 2021-10-22T09:00:00+02:00
draft: false
description: "Tutorial on setting up a self-hosted git service with gitea on docker and docker-compose, a open-source alternative to Github and Gitlab."
tags: ["docker", "gitea", "git"]
categories: ["containers"]
---

**[Gitea](https://gitea.io/en-us/)** is a self-hosted [git](https://en.wikipedia.org/wiki/Git) service written in Go, its super lightweight to run and supports ARM architectures as well, so you can run it on a Raspberry Pi as well.

## What are we doing today

In this tutorial we will be setting up a self hosted version control repository with **[Gitea](https://gitea.io/en-us/)** on **[Docker](https://docs.docker.com/get-docker/)** using **[Traefik](https://traefik.io/)** as our Load Balancer and SSL terminations for LetsEncrypt certificates.

We will then create a example git repository, add our ssh key to our account and clone our repository using ssh, change some code, commit and push to our repository.

## Assumptions

I will assume that you have [docker](https://docs.docker.com/get-docker/) and [docker-compose](https://docs.docker.com/compose/install/) installed. If you need more info on [Traefik](https://traefik.io/) you can have a look at their website, but I have also written a post on [setting up Traefik v2](https://containers.fan/posts/setup-traefik-v2-docker-compose/) in detail, but we will touch on that in this post.

## Environment Details

I have 1 DNS entry set to the following:

- Traefik: `traefik.rbkr.xyz`
- Gitea: `git.rbkr.xyz`

Accessing our service will be done over `HTTPS` on port `443`, and for cloning over `SSH`, the port will be set to `222`.

## Directory Structure

Create the `gitea` directory which will be our docker compose project directory:

```bash
mkdir gitea
cd gitea
```

Create the traefik directory for `acme.json` where certificate data will be stored, create the file and change permissions on the file:

```bash
touch traefik/acme.json
chmod 600 traefik/acme.json
```

## Traefik

Open the `docker-compose.yml` and add the first bit which will Traefik, ensure that you replace the following:

- `me@example.com` with your email under `certificatesResolvers.letsencrypt.acme.email`
- `traefik.rbkr.xyz` with your fqdn for traefik under `traefik.http.routers.api.rule=Host()`

The section for traefik:

```yaml
version: '3.8'

services:
  gitea-traefik:
    image: traefik:2.4
    container_name: gitea-traefik
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
      - '--certificatesResolvers.letsencrypt.acme.email=me@example.com`'
      - '--certificatesResolvers.letsencrypt.acme.storage=acme.json'
      - '--certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=http'
      - '--log=true'
      - '--log.level=INFO'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

networks:
  public:
    name: public
```

We can start traefik so long:

```bash
docker-compose up -d
```

## Gitea

Now we will add the Gitea components, I have opted in for the gitea service and a redis cache and will be making use of sqlite as this is just a demonstration. 

For non-test environments, you can have a look at MySQL or Postres:

- https://docs.gitea.io/en-us/install-with-docker/#databases

Review the following configuration options:

- `DOMAIN` and `SSH_DOMAIN` (this will be used in your clone urls)
- `ROOT_URL` (this is set to use the HTTPS protocol, including my domain)
- `SSH_LISTEN_PORT` (this is the port listening for SSH inside the container)
- `SSH_PORT` (this is the port we are exposing from outside, which will be replaced in the clone url)
- `DB_TYPE` (Im using sqlite for this example)
- `traefik.http.routers.gitea.rule=Host()` (the host header to reach gitea via web)
- `./data/gitea` (I am persisting the data in my local working directory under the given path)

The gitea portion of the `docker-compose.yml`:

```yaml
---
version: '3.8'

services:
  ...
  gitea:
    container_name: gitea
    image: gitea/gitea:${GITEA_VERSION:-1.14.5}
    restart: unless-stopped
    depends_on:
      gitea-traefik:
        condition: service_started
      gitea-cache:
        condition: service_healthy
    environment:
      - APP_NAME="Gitea"
      - USER_UID=1000
      - USER_GID=1000
      - USER=git
      - RUN_MODE=prod
      - DOMAIN=git.rbkr.xyz
      - SSH_DOMAIN=git.rbkr.xyz
      - HTTP_PORT=3000
      - ROOT_URL=https://git.rbkr.xyz
      - SSH_PORT=222
      - SSH_LISTEN_PORT=22
      - DB_TYPE=sqlite3
      - GITEA__cache__ENABLED=true
      - GITEA__cache__ADAPTER=redis
      - GITEA__cache__HOST=redis://gitea-cache:6379/0?pool_size=100&idle_timeout=180s
      - GITEA__cache__ITEM_TTL=24h
    ports:
      - "222:22"
    networks:
      - public
    volumes:
      - ./data/gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.gitea.rule=Host(`git.rbkr.xyz`)"
      - "traefik.http.routers.gitea.entrypoints=https"
      - "traefik.http.routers.gitea.tls.certresolver=letsencrypt"
      - "traefik.http.routers.gitea.service=gitea-service"
      - "traefik.http.services.gitea-service.loadbalancer.server.port=3000"
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  gitea-cache:
    container_name: gitea-cache
    image: redis:6-alpine
    restart: unless-stopped
    networks:
      - public
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 15s
      timeout: 3s
      retries: 30
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
  ...

```

So my complete `docker-compose.yml` will look like the following:

```yaml
---
version: '3.8'

services:
  gitea-traefik:
    image: traefik:2.4
    container_name: gitea-traefik
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

  gitea:
    container_name: gitea
    image: gitea/gitea:${GITEA_VERSION:-1.14.5}
    restart: unless-stopped
    depends_on:
      gitea-traefik:
        condition: service_started
      gitea-cache:
        condition: service_healthy
    environment:
      - APP_NAME="Gitea"
      - USER_UID=1000
      - USER_GID=1000
      - USER=git
      - RUN_MODE=prod
      - DOMAIN=git.rbkr.xyz
      - SSH_DOMAIN=git.rbkr.xyz
      - HTTP_PORT=3000
      - ROOT_URL=https://git.rbkr.xyz
      - SSH_PORT=222
      - SSH_LISTEN_PORT=22
      - DB_TYPE=sqlite3
      - GITEA__cache__ENABLED=true
      - GITEA__cache__ADAPTER=redis
      - GITEA__cache__HOST=redis://gitea-cache:6379/0?pool_size=100&idle_timeout=180s
      - GITEA__cache__ITEM_TTL=24h
    ports:
      - "222:22"
    networks:
      - public
    volumes:
      - ./data/gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.gitea.rule=Host(`git.rbkr.xyz`)"
      - "traefik.http.routers.gitea.entrypoints=https"
      - "traefik.http.routers.gitea.tls.certresolver=letsencrypt"
      - "traefik.http.routers.gitea.service=gitea-service"
      - "traefik.http.services.gitea-service.loadbalancer.server.port=3000"
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  gitea-cache:
    container_name: gitea-cache
    image: redis:6-alpine
    restart: unless-stopped
    networks:
      - public
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 15s
      timeout: 3s
      retries: 30
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

networks:
  public:
    name: public
```

Once your configuration is updated, start gitea:

```bash
docker-compose up -d

Creating network "public" with the default driver
Creating gitea-traefik ... done
Creating gitea-cache   ... done
Creating gitea         ... done
```

Once the containers has started, verify that they are all up:

```bash
docker-compose ps
    Name                   Command                  State                                       Ports
--------------------------------------------------------------------------------------------------------------------------------------
gitea           /usr/bin/entrypoint /bin/s ...   Up             0.0.0.0:222->22/tcp,:::222->22/tcp, 3000/tcp
gitea-cache     docker-entrypoint.sh redis ...   Up (healthy)   6379/tcp
gitea-traefik   /entrypoint.sh --api --pro ...   Up             0.0.0.0:443->443/tcp,:::443->443/tcp, 0.0.0.0:80->80/tcp,:::80->80/tcp
```

## Installation and Configuration

Head over to the `ROOT_URL` of your gitea installation, in my case it looked like the following:

![gitea-container](https://user-images.githubusercontent.com/567298/138003899-63d0cfd8-ca97-4e9f-b9d6-224987105d03.png)

If you are not automatically redirected to register an account, select "Register" in the top right side:

![gitea-register](https://user-images.githubusercontent.com/567298/138001952-5bf32a22-5287-4d4f-b852-6860dd6417af.png)

If you would like to make use of email, configure your email settings here:

![gitea-email](https://user-images.githubusercontent.com/567298/138002011-f261870d-2fcc-4809-8d12-8317fa252de3.png)

Then configure the admin account:

![gitea-admin-account](https://user-images.githubusercontent.com/567298/138422959-8637e282-7393-4cc2-b942-fe65cf6ea80f.png)

Once you are logged in, you should see the following screen:

![gitea](https://user-images.githubusercontent.com/567298/138002202-818a364c-74a9-4be9-8963-cd151d10d96f.png)

## SSH Key

Now we would like to create a SSH key so that we can authorize our git client to pull and push to/from Gitea:

```bash
ssh-keygen -f ~/.ssh/gitea-demo -t rsa -C "Gitea-Demo" -q -N ""
```

Then head to your profile, select settings:

![gitea](https://user-images.githubusercontent.com/567298/138002368-679ca1eb-81a3-4a83-8aaf-e5c182305be4.png)

Select the SSH Tab and select "Add Key":

![gitea](https://user-images.githubusercontent.com/567298/138002437-a43fbd5b-92a6-40b8-abb1-ebe78c8a5c67.png)

Head back to your terminal and copy your public ssh key from the key that we created earlier:

```bash
cat ~/.ssh/gitea-demo.pub
ssh-rsa AAAAB[x----redacted----x]/en5QDz3vI18n1u4lrKu1YsTR57YL Gitea-Demo
```

Then paste the public key into the form and add the key, you should then see the key present in gitea:

![gitea](https://user-images.githubusercontent.com/567298/138002601-be049746-fcb6-46ad-a931-bfa11d1725b2.png)

## Create a Git Repository

Now head back to the "Dashboard", then select the "+" sign at the top and create a "New Repository":

![gitea](https://user-images.githubusercontent.com/567298/138002657-054e9e6a-25bd-4f4a-9bdb-ef368a720e5f.png)

From the repo form, I will be naming my repository "hello-world":

![gitea](https://user-images.githubusercontent.com/567298/138002751-88ff1793-b6e4-4ac4-886d-d4826e152ffa.png)

Then I selected "Initialise repository with Readme" and I selected to create the repository:

![gitea](https://user-images.githubusercontent.com/567298/138002819-69ce233d-c073-4ed4-a714-1762d34f5b47.png)

Now when we select the repo, we should see it in the Gitea UI:

![gitea](https://user-images.githubusercontent.com/567298/138002865-2e9cc6d9-3fea-4f32-91b8-6199063b7d4f.png)

To clone the repository via SSH, select the "SSH" button and click copy to clipboard:

![gitea](https://user-images.githubusercontent.com/567298/138002962-962b746f-619e-4f08-b058-6d8f4d719e89.png)

Before we clone the repo on our terminal, let's setup the ssh-agent to be active for 1 hour:

```
eval $(ssh-agent -t 3600)
```

Then add the ssh key to the ssh-agent:

```
ssh-add ~/.ssh/gitea-demo

Identity added: ~/.ssh/gitea-demo (Gitea-Demo)
```

*Optional:* If you have a non default ssh key, like the above and you don't want to make use of `ssh-agent` you can setup a SSH Config, for example in `~/.ssh/config`:

```
# Globals
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  #AddKeysToAgent yes
  #IdentityFile ~/.ssh/id_rsa
  ServerAliveInterval 60
  ServerAliveCountMax 30

# Gitea
Host git.rbkr.xyz
  IdentityFile ~/.ssh/gitea-demo
  User git
  Port 222
```

Now let's clone the repository:

```
git clone ssh://git@git.rbkr.xyz:222/ruanbekker/hello-world.git

Cloning into 'hello-world'...
Warning: Permanently added '[git.rbkr.xyz]:222,[95.x.x.x]:222' (ECDSA) to the list of known hosts.
remote: Enumerating objects: 3, done.
remote: Counting objects: 100% (3/3), done.
remote: Total 3 (delta 0), reused 0 (delta 0), pack-reused 0
Receiving objects: 100% (3/3), done.
```

Change into the directory which we cloned:

```
cd hello-world
```

Let's update the `README.md` file with any content, then after we saved the file, we can see that the file has been changed:

```
git status

On branch master
Your branch is up to date with 'origin/master'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   README.md

no changes added to commit (use "git add" and/or "git commit -a")
```

Add the file, commit and push to master:

```bash
git add README.md
git commit -m "Update readme for blogpost"
git push origin master

Writing objects: 100% (3/3), 305 bytes | 305.00 KiB/s, done.
Total 3 (delta 0), reused 0 (delta 0), pack-reused 0
remote: . Processing 1 references
remote: Processed 1 references in total
To ssh://git.rbkr.xyz:222/ruanbekker/hello-world.git
   7804b67..85550dd  master -> master
```

## View the changes

When we head back to the Gitea UI, we can see the README file has been updated, and we can see a git commit sha as well:

![gitea-ui](https://user-images.githubusercontent.com/567298/138003524-0eb7de18-f90d-4671-8d29-1e6614529743.png)

In order to see what changed, we can click on the git commit sha:

![gitea-commit](https://user-images.githubusercontent.com/567298/138003595-262b2f43-06dc-4881-8277-bab17b2ef005.png)

## Swagger API

Gitea ships with Swagger by default and the endpoint is `/api/swagger` which in my case is accessible via:

- https://git.rbkr.xyz/api/swagger

And it looks like the following:

![gitea-swagger](https://user-images.githubusercontent.com/567298/138003950-c9e06f77-3ce6-434e-bf10-a10dcdf68f56.png)

## Thank You

I hope this was helpful, I was really impressed with Gitea. If you liked this content, please make sure to share or come say hi on my website or twitter:

  * **Website**: [ruan.dev](https://ruan.dev)
  * **Twitter**: [@ruanbekker](https://twitter.com/ruanbekker)
