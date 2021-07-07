---
title: "Setup RocketChat Communication Platform on Docker"
date: 2021-07-07T21:00:00+02:00
draft: false
description: "Learn how to setup a self-hosted open source communication platform called rocketchat on docker and use traefik as our http proxy with letsencrypt ssl traefik for secure communication"
tags: ["docker", "containers", "traefik", "rocketchat", "security"]
categories: ["containers"]
---

In this post we will setup a self-hosted open source communication platform called [rocket chat](https://rocket.chat/) on docker, using docker compose and we will secure our traffic with https using traefik and letsencrypt.

## What is Rocket Chat?

![rocketchat](https://user-images.githubusercontent.com/567298/124833265-369c0500-df7e-11eb-9358-3fcfdaa93cc6.png)

RocketChat is a awesome self-hosted open source chat server. If you are familliar with Slack, RocketChat is a open-source alternative.

## Installing Rocket Chat

We will be using Traefik to do SSL termination and host based routing, if you don't have Traefik running already, you can follow this post to get that set up:
- https://containers.fan/posts/setup-traefik-v2-docker-compose/

Rocket Chat requires MongoDB as its database to store its configuration and data and if you would like to view their official installation guide for multiple ways of deploying rocket chat, you can visit [this](https://rocket.chat/install/) link.

The `docker-compose.yml` file for our mongodb and rocketchat containers:

```yaml
version: "3.8"

services:
  rocketchat:
    image: rocketchat/rocket.chat:latest
    container_name: rocketchat
    restart: unless-stopped
    command: >
      bash -c
        "for i in `seq 1 30`; do
          INSTANCE_IP=$$(hostname -i) node main.js &&
          s=$$? && break || s=$$?;
          sleep 5;
        done; (exit $$s)"
    volumes:
      - ./app/data/uploads:/app/uploads
      - /tmp:/tmp
    environment:
      - PORT=3000
      - ROOT_URL=http://chat.yourdomain.net
      - MONGO_URL=mongodb://rocketchat-mongo:27017/rocketchat
      - MONGO_OPLOG_URL=mongodb://rocketchat-mongo:27017/local
    ports:
      - 9458:9458 # prometheus
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.rocketchat-app.rule=Host(`chat.yourdomain.net`)"
      - "traefik.http.routers.rocketchat-app.entrypoints=https"
      - "traefik.http.routers.rocketchat-app.tls.certresolver=letsencrypt"
    depends_on:
      - rocketchat-mongo
    networks:
      - public
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  rocketchat-mongo:
    image: mongo:4.0
    container_name: rocketchat-mongo
    restart: unless-stopped
    command: mongod --oplogSize 128 --replSet rs0
    volumes:
      - ./mongo/data/db:/data/db
      - ./mongo/data/backups:/dump
    networks:
      - public
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  rocketchat-mongo-init-replica:
    image: mongo:4.0
    container_name: rocketchat-mono-init-replica
    command: >
      bash -c
        "for i in `seq 1 30`; do
          mongo rocketchat-mongo/rocketchat --eval \"
            rs.initiate({
              _id: 'rs0',
              members: [ { _id: 0, host: 'localhost:27017' } ]})\" &&
          s=$$? && break || s=$$?;
          sleep 5;
        done; (exit $$s)"
    depends_on:
      - rocketchat-mongo
    networks:
      - public
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

networks:
  public:
    name: public
```

Make sure to replace the FQDN of your choice, as I used `chat.yourdomain.net` as an example.

Once everything is in place, boot the stack:

```bash
docker-compose up -d
```

## Access and Registration

If you used Traefik, you should be able to access RocketChat on `https://chat.yourdomain.net` where you will be able to register your admin account. Make sure to follow the [administration documentation](https://docs.rocket.chat/guides/administrator-guides/administration) to setup your server to the way you desire. The important settings I used, was to manual approve new registrations, configured SMTP settings for 2FA and modify the permissions of user roles.

## Desktop Client

RocketChat offers Desktop and Mobile applications which can be accessed [here](https://rocket.chat/install/), for this demonstration we will be installing the desktop application for Mac.

Once you install the app, you will be prompted for your server url:

![rocketchat](https://user-images.githubusercontent.com/567298/124832258-ad380300-df7c-11eb-87ec-bb671bd8e987.png)

Once you entered your server url, you will be able to log in:

![rocketchat](https://user-images.githubusercontent.com/567298/124832296-bd4fe280-df7c-11eb-8346-c8746dbd6ab3.png)

After you logged in, you should be able to send messages and use rocket chat:

![rocketchat](https://user-images.githubusercontent.com/567298/124832500-0f910380-df7d-11eb-922a-858e59061e5f.png)

## Thank You

Thanks for reading, if you like my content, check out my **[website](https://ruan.dev)** or follow me at **[@ruanbekker](https://twitter.com/ruanbekker)** on Twitter.
