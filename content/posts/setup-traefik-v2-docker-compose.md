---
title: "Run Traefik version 2 on Docker"
date: 2021-06-16T18:00:00+02:00
draft: false
description: "Run traefik version 2 on docker and learn how to hook up a application behind the proxy"
tags: ["docker", "containers", "traefik"]
categories: ["containers"]
---

In this tutorial we will be setting up [Traefik ](https://traefik.io) v2 as our reverse proxy with port 80 and 443 enabled, and then hook up a example application behind the application load balancer, and route incoiming requests via host headers.

## What is Traefik

Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices super easy by making use of docker labels to route your traffic based on host headers, path prefixes etc. Please check out [their website](https://doc.traefik.io/traefik/) to find out more about them.

## Use Case

In our example we want to route traefik from `http://app.mydomain.net` to hit our proxy on port 80, then we want traefik to redirect port 80 to the 443 port configured on the proxy which is configured with letsencrypt and reverse proxy the connection to our application.

The application is being configured via docker labels, which we will get into later.

## Traefik on Docker

We will have one `docker-compose.yml` file which has the proxy and the example application:

```yaml
---
version: '3.8'

services:
  traefik:
    image: traefik:2.4
    container_name: traefik
    restart: unless-stopped
    volumes:
      - ./traefik/acme.json:/acme.json
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - docknet
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.api.rule=Host(`traefik.mydomain.net`)'
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
      - '--certificatesResolvers.letsencrypt.acme.email=youremail@yourdomain.net'
      - '--certificatesResolvers.letsencrypt.acme.storage=acme.json'
      - '--certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=http'
      - '--log=true'
      - '--log.level=INFO'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  webapp:
    image: traefik/whoami
    container_name: webapp
    restart: unless-stopped
    networks:
      - docknet
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.webapp.rule=Host(`app.mydomain.net`)'
      - 'traefik.http.routers.webapp.entrypoints=https'
      - 'traefik.http.routers.webapp.tls=true'
      - 'traefik.http.routers.webapp.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.webapp.service=webappservice'
      - 'traefik.http.services.webappservice.loadbalancer.server.port=80'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

networks:
  docknet:
    name: docknet
```

Prepare the `./traefik/acme.json` file:

```
mkdir traefik
touch traefik/acme.json
chmod 600 traefik/acme.json
```

As you can see in order to wire a application onto the proxy we need the following labels:

```yaml
      - 'traefik.enable=true'
      - 'traefik.http.routers.webapp.rule=Host(`app.mydomain.net`)'
      - 'traefik.http.routers.webapp.entrypoints=https'
      - 'traefik.http.routers.webapp.tls=true'
      - 'traefik.http.routers.webapp.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.webapp.service=webappservice'
      - 'traefik.http.services.webappservice.loadbalancer.server.port=80'
```

Now boot our stack using docker-compose:

```bash
docker-compose up -d
```

The certificate process might take anything from 5-60s in my experience.

## Test the Application

Now that our container is running, make a http request using curl with the configured domain name:

```bash
curl -IL http://app.mydomain.net:80
```

Replace the domain with the configured domain that you own and everything should be up and running. We can also access the traefik dashboard using the configured domain, in this case `traefik.mydomain.net`

## Thank You

Thanks for reading, if you like my content, check out my **[website](https://ruan.dev)** or follow me at **[@ruanbekker](https://twitter.com/ruanbekker)** on Twitter.
