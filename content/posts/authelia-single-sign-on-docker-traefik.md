---
title: "Single Sign-On with Authelia on Docker"
date: 2023-03-26T18:00:00+02:00
draft: false
description: "This tutorial will have a look at Authelia and making use of single sign-on for your web services."
tags: ["docker", "authelia", "traefik", "security"]
categories: ["containers"]
---

In this post we will be looking at Authelia which is a authentication and authorization service using Traefik on Docker containers. We will explore how to secure our web services and use single sign on with multi-factor authentication.

## About

From [Authelia's](https://www.authelia.com/) website:

> "Authelia is an open-source authentication and authorization server and portal fulfilling the identity and access management (IAM) role of information security in providing multi-factor authentication and single sign-on (SSO) for your applications via a web portal. It acts as a companion for common reverse proxies."

## Prerequisites

I will be using Traefik Proxy, If you are following along, you can find a tutorial to get Traefik installed, below:
- https://containers.fan/posts/setup-traefik-v2-docker-compose/

## Setup

Create the authelia project directory:

```bash
mkdir -p authelia-demo/{data,config}
cd authelia-demo
```

Create the `docker-compose.yml` with the following content:

```yaml
---
version: '3.8'

services:
  authelia-service:
    image: authelia/authelia:4
    container_name: authelia-service
    restart: unless-stopped
    environment:
      - TZ=Africa/Johannesburg
    volumes:
      - ./config:/config
      - ./data:/data
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.authelia.rule=Host(`auth.demo.containers.fan`)'
      - 'traefik.http.routers.authelia.entrypoints=https'
      - 'traefik.http.routers.authelia.tls=true'
      - 'traefik.http.routers.authelia.tls.certresolver=letsencrypt'
      - 'traefik.http.middlewares.authelia.forwardauth.address=http://authelia-service:9091/api/verify?rd=https://auth.demo.containers.fan'
      - 'traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true'
      - 'traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email'
    depends_on:
      - authelia-redis
    networks:
      - docknet
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  authelia-redis:
    image: redis:7
    container_name: authelia-redis
    restart: unless-stopped
    environment:
      - TZ=Africa/Johannesburg
    networks:
      - docknet
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  one-factor-service:
    image: ruanbekker/web-center-name-v2
    container_name: one-factor-service
    restart: unless-stopped
    environment:
      - APP_TITLE=One Factor Service
      - APP_URL=
      - APP_TEXT=
    depends_on:
      - authelia-service
    networks:
      - docknet
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.one-factor.rule=Host(`one-factor.demo.containers.fan`)'
      - 'traefik.http.routers.one-factor.entrypoints=https'
      - 'traefik.http.routers.one-factor.tls=true'
      - 'traefik.http.routers.one-factor.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.one-factor.middlewares=authelia@docker'
      - 'traefik.http.routers.one-factor.service=one-factor-service'
      - 'traefik.http.services.one-factor-service.loadbalancer.server.port=5000'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  two-factor-service:
    image: ruanbekker/web-center-name-v2
    container_name: two-factor-service
    restart: unless-stopped
    environment:
      - APP_TITLE=Two Factor Service
      - APP_URL=
      - APP_TEXT=
    depends_on:
      - authelia-service
    networks:
      - docknet
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.two-factor.rule=Host(`two-factor.demo.containers.fan`)'
      - 'traefik.http.routers.two-factor.entrypoints=https'
      - 'traefik.http.routers.two-factor.tls=true'
      - 'traefik.http.routers.two-factor.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.two-factor.middlewares=authelia@docker'
      - 'traefik.http.routers.two-factor.service=two-factor-service'
      - 'traefik.http.services.two-factor-service.loadbalancer.server.port=5000'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  public-service:
    image: ruanbekker/web-center-name-v2
    container_name: public-service
    restart: unless-stopped
    environment:
      - APP_TITLE=Public Service
      - APP_URL=
      - APP_TEXT=
    depends_on:
      - authelia-service
    networks:
      - docknet
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.public.rule=Host(`public.demo.containers.fan`)'
      - 'traefik.http.routers.public.entrypoints=https'
      - 'traefik.http.routers.public.tls=true'
      - 'traefik.http.routers.public.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.public.middlewares=authelia@docker'
      - 'traefik.http.routers.public.service=public-service'
      - 'traefik.http.services.public-service.loadbalancer.server.port=5000'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

networks:
  docknet:
    name: docknet
```

The config in `config/configuration.yml`:

```yaml
---
server.host: 0.0.0.0
server.port: 9091
log:
  level: debug

jwt_secret: c50498e29383564cd50bdeda9b74a3bf

default_redirection_url: https://public.demo.containers.fan
totp:
  issuer: demo.containers.fan

authentication_backend:
  file:
    path: /config/users_database.yml

access_control:
  default_policy: deny
  rules:
    - domain: public.demo.containers.fan
      policy: bypass
    - domain: one-factor.demo.containers.fan
      policy: one_factor
    - domain: two-factor.demo.containers.fan
      policy: two_factor

session:
  name: authelia_session
  secret: unsecure_session_secret
  expiration: 3600                     # 1 hour
  inactivity: 300                      # 5 minutes
  domain: demo.containers.fan          # Should match whatever your root protected domain is

  redis:
    host: authelia-redis
    port: 6379

regulation:
  max_retries: 3
  find_time: 120
  ban_time: 300

storage:
  encryption_key: f30ebde68b2c85c1b3fe2d16d9884190
  local:
    path: /data/db.sqlite3

notifier:
  smtp:
    username: apikey
    password: secret
    host: smtp.sendgrid.net
    port: 587
    sender: no-reply@mydomain.com
```

Generate a password hash:

```bash
$ docker run --rm -it authelia/authelia:4 authelia hash-password password123
Password hash: $argon2id$v=19$m=65536,t=1,p=8$ek9jRWNRbkhPMVNNWWpreg$myvpTCREAwhITbcD80d2Ae5+pdIK3Y3SSNuLSU8dezw
```

The user database defined in `config/users_database.yml`:

```yaml
---
users:
  authelia:
    displayname: "authelia"
    password: "$argon2id$v=19$m=65536,t=1,p=8$ek9jRWNRbkhPMVNNWWpreg$myvpTCREAwhITbcD80d2Ae5+pdIK3Y3SSNuLSU8dezw"
    email: x@x.com
    groups:
      - admins
      - dev
  ruan:
    displayname: "Ruan"
    email: "x@gmail.com"
    password: "$argon2id$v=19$m=65536,t=1,p=8$Q3YwxUdRTnhDbVkxS1JBVx$TNnK9Fku8QfnWovquhdkixDNBn0juhN1upSY9fRcVzA"
    groups:
      - admins
      - dev
```

Boot the stack:

```bash
docker-compose up -d
```

## Access our Services

First we will access the public service:

<img width="918" alt="image" src="https://user-images.githubusercontent.com/567298/172251405-ea1d5b56-3220-4a7c-8e8e-17d7596513da.png">

Next we will access the one factor service on https://one-factor.demo.containers.fan then we will be redirected to auth.demo.containers.fan:

<img width="1146" alt="image" src="https://user-images.githubusercontent.com/567298/172254488-fbd842fd-e909-4735-9871-7a0ba88b9a0b.png">

Then we provide the username and password combination that we provided in `config/user_database.yml`, which was `ruan` as the username and the password `password123`, then if the credentials was passed correctly, we will be redirected to our service:

<img width="1145" alt="image" src="https://user-images.githubusercontent.com/567298/172254905-90201549-35c3-42f3-9d37-939639d9048f.png">

For our two factor service, we first need to logon to authelia and create and MFA device on https://auth.demo.containers.fan:

<img width="1144" alt="image" src="https://user-images.githubusercontent.com/567298/172256077-eb5474b7-e3be-4209-868a-11953602664a.png">

Then select "Register device", then you should receive an email with the instructions to associate a MFA device to your account:

<img width="627" alt="image" src="https://user-images.githubusercontent.com/567298/172256458-e3e01720-11df-4b34-a175-96d5c7b3d2eb.png">

Once you click on the link you will get the barcode to scan the qr code for MFA:

![image](https://user-images.githubusercontent.com/567298/172257065-71eac9e3-6f32-418c-9442-7262dd182ce0.png)

If you want an alternative way to setup your advice, you can copy the private key by clicking the key icon, once you have setup your MFA device, select "Done", then provide a one-time password to verify:

<img width="951" alt="image" src="https://user-images.githubusercontent.com/567298/172257538-7dbc5e0e-290f-4361-883a-aecb61b0b297.png">

To test the whole flow, logout from authelia, by selecting "Logout":

<img width="953" alt="image" src="https://user-images.githubusercontent.com/567298/172257881-a02d3a34-e216-4f51-9ed0-91349457ebb5.png">

Head over to https://two-factor.demo.containers.fan then provide your username and password:

<img width="951" alt="image" src="https://user-images.githubusercontent.com/567298/172258078-030091c4-5974-45ef-ae30-11cf4a4b3f47.png">

Then provide the one-time pin from your MFA device:

<img width="950" alt="image" src="https://user-images.githubusercontent.com/567298/172258150-fb505b44-cd20-461f-8393-76840a2f5101.png">

If the challenge was successful, you should be redirected to the service:

<img width="950" alt="image" src="https://user-images.githubusercontent.com/567298/172258258-e73c2a66-3c22-4022-a16b-4c6f3c0582db.png">

Once you are authenticated to authelia, you will be able to access the service without authenticating again.


## Thank You

Thanks for reading, feel free to check out my [website](https://ruan.dev/), feel free to subscribe to my [newsletter](http://digests.ruanbekker.com/?via=ruanbekker-blog) or follow me at [@ruanbekker](https://twitter.com/ruanbekker) on Twitter.

- Linktree: https://go.ruan.dev/links
- Patreon: https://go.ruan.dev/patreon
- Ko-Fi: https://ko-fi.com/ruanbekker
