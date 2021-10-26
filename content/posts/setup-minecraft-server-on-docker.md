---
title: "Setup a Minecraft Server on Docker"
date: 2021-10-26T06:00:00+02:00
draft: false
description: "Tutorial on how to setup a Minecraft Game Server on Docker."
tags: ["docker", "games", "server", "minecraft"]
categories: ["containers"]
---

![minecraft](https://cdn.worldvectorlogo.com/logos/minecraft.svg)

This post will show how to setup your own [minecraft](https://www.minecraft.net/en-us) game server on [docker](https://docker.com) using [docker-compose](https://docs.docker.com/compose/install/).

## Requirements

As we will run minecraft as a docker container, we require [docker](https://docs.docker.com/get-docker/) and [docker-compose](https://docs.docker.com/compose/install/). You can follow the links to their website for instructions to install it.

In summary it will be the following to install docker:

```bash
curl https://get.docker.com | bash
sudo usermod -aG docker $USER
```

And the following to install docker-compose:

```bash
sudo curl -L "https://github.com/docker/compose/releases/download/1.28.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

Note that I installed version 1.28.5, in future this may be outdated, so I recommend getting the latest version from [their](https://docs.docker.com/compose/install/) website.

You can verify if docker and docker-compose was installed by running:

```bash
docker --version
docker-compose --version
```

## Configuration

Create the project directory:

```bash
mkdir -p ~/mincraft
```

Change to the directory:

```bash
cd ~/minecraft
```

Create the `docker-compose.yml` file and open it with your editor of choice, then provide this content:

```yaml
version: "3.8"

services:
  minecraft-server:
    image: itzg/minecraft-server:latest
    container_name: minecraft-server
    ports:
      - 25565:25565
    environment:
      SERVER_NAME: "Dockerized-Minecraft-Server"
      MOTD: "Forge Minecraft Server"
      EULA: "TRUE"
      TYPE: "FORGE"
      VERSION: "1.17.1"
      MODE: "survival"
      MEMORY: "1G"
      LEVEL_TYPE: "DEFAULT"
      ENABLE_RCON: "true"
      RCON_PASSWORD: password
      RCON_PORT: 28016
      SERVER_PORT: 25565
      ENABLE_WHITELIST: "true"
      WHITELIST: "${WHITELISTED_PLAYERS}"
      OPS: "${OPS_PLAYERS}"
      MAX_PLAYERS: 20
      ANNOUNCE_PLAYER_ACHIEVEMENTS: "true"
      SPAWN_ANIMALS: "true"
      SPAWN_MONSTERS: "true"
      PVP: "true"
      LEVEL: "cold"
      TZ: "Africa/Johannesburg"
      GUI: "FALSE"
      MODS_FILE: /extras/mods.txt
      REMOVE_OLD_MODS: "true"
    restart: unless-stopped
    user: "${UID}:${GID}"
    volumes:
      - ./data:/data
      - ./mods.txt:/extras/mods.txt:ro
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
```

We want the user creating the data directory to be the same user that we are using to avoid permission issues, so we need to create a `.env` file and set the `UID` and `GID` values to the userid and groupid of our user:

```bash
echo UID=$(id -u) > .env
echo GID=$(id -g) >> .env
```

Yours will most probably differ, but mine look like this:

```bash
cat .env
UID=501
GID=20
```

Next we need to set the whitelisted and ops players in `WHITELISTED_PLAYERS` and `OPS_PLAYERS` so the end result will look something like this:

```bash
UID=501
GID=20
WHITELISTED_PLAYERS=mygamertag,player2,player3
OPS_PLAYERS=mygamertag
```

If you don't want mods, you can remove `MODS_FILE` and `REMOVE_OLD_MODS` entry, but in this case I will be installing the [Fast Leaf Decay](https://www.curseforge.com/minecraft/mc-mods/fast-leaf-decay/) mod from curseforge.com.

Create the file `~/minecraft/mods.txt` and add the jar that you want to add to the file, as example:

```
https://media.forgecdn.net/files/3399/353/FastLeafDecay-26.jar
```

## Start the Minecraft Server

Once that is in place, start the minecraft server:

```bash
docker-compose up -d
```

While the server is booting, you can follow the logs:

```bash
docker-compose logs -f minecraft-server
...
minecraft-server      | [20:18:55] [modloading-worker-1/INFO]: Forge mod loading, version 37.0.103, for MC 1.17.1 with MCP 20210706.113038
minecraft-server      | [20:18:55] [modloading-worker-1/INFO]: MinecraftForge v37.0.103 Initialized
minecraft-server      | [20:19:00] [main/INFO]: Reloading ResourceManager: Default, forge-1.17.1-37.0.103-universal.jar, FastLeafDecay-26.jar
minecraft-server      | [20:19:06] [Server thread/INFO]: Starting Minecraft server on *:25565
minecraft-server      | [20:19:10] [Server thread/INFO]: Preparing level "cold"
minecraft-server      | [20:19:12] [Worker-Main-2/INFO]: Preparing spawn area: 0%
minecraft-server      | [20:19:18] [Worker-Main-2/INFO]: Preparing spawn area: 9%
minecraft-server      | [20:19:19] [Worker-Main-2/INFO]: Preparing spawn area: 23%
minecraft-server      | [20:19:20] [Server thread/INFO]: Time elapsed: 9527 ms
minecraft-server      | [20:19:20] [Server thread/INFO]: Done (9.928s)! For help, type "help"
minecraft-server      | [20:19:20] [Server thread/INFO]: Starting remote control listener
minecraft-server      | [20:19:20] [Server thread/INFO]: Thread RCON Listener started
minecraft-server      | [20:19:20] [Server thread/INFO]: RCON running on 0.0.0.0:28016
minecraft-server      | [20:19:20] [RCON Listener #1/INFO]: Thread RCON Client /172.19.0.3 started
```

Once the server is booted, we can verify by using the healthcheck command:

```bash
docker exec -it minecraft-server mc-monitor status

localhost:25565 : version=1.17.1 online=0 max=20 motd='Forge Minecraft Server'
```

## Minecraft Command Line

We can access the minecraft command line with the following:

```bash
docker-compose exec minecraft-server rcon-cli
> 
```

To list our whitelisted players:

```bash
> /whitelist list
There are 3 whitelisted players: x, x, x
```

To restart the server:

```
> /stop
```

## Install Minecraft

Install minecraft java edition on your PC from:
- https://www.minecraft.net/en-us/download

Once installed, install the forge client:
- https://files.minecraftforge.net/net/minecraftforge/forge/

Open minecraft and you should see the forge under our installations:

![minecraft](https://user-images.githubusercontent.com/567298/136714729-d37a9428-75c0-416c-9107-bb9604ce422e.png)

When we run our forge installation you should see something like this:

![minecraft](https://user-images.githubusercontent.com/567298/136714751-fdf10fec-a1cd-4ea4-937d-7305f119891e.png)

Then on the multiplayer section you should see the servers below:

![minecraft](https://user-images.githubusercontent.com/567298/138816528-4eff80e0-7289-440b-81d1-5223390404af.png)

You will most probably have no servers by default, so then add your server, you will need the IP Address of where minecraft is running:

![minecraft](https://user-images.githubusercontent.com/567298/138816726-5107c9d6-65a5-4a88-b49b-e1c500b0a484.png)

Save it and join your server and you should be connected to your server.

## Note on Forge Mods

For forge mods to work properly you need the mods on the server and client side, for more info, see this issue:
- https://github.com/itzg/docker-minecraft-server/issues/1086

## Backups

Create the directories for the script and backup locations:

```
sudo mkdir -p /opt/backups /opt/scripts
```

Change the permissions of those directories:

```
sudo chown -R "$(id -u):$(id -g)" /opt
```

Create the backup script in `/opt/scripts/backup_minecraft.sh` with the following content:

```bash
#!/usr/bin/env bash
tar -zcvf /opt/backups/minecraft/backup-$(date +%F).tar.gz ~/minecraft
find /opt/backups/minecraft/ -type f -name "backup-*.tar.gz" -mtime +7 -exec rm {} \;
```

This script will compress the minecraft project directory in a archive and delete any backups older than 7 days, which we will run under a cronjob. 

Change the permissions of our backup script to make it executable:

```
chmod +x /opt/scripts/backup_minecraft.sh
```

Open crontab with `crontab -e` and add the cron expression to backup daily at 00:00:

```
00 00 * * * /opt/scripts/backup_minecraft.sh
```

## Getting Started Guide

This is a nice tutorial I stumbled upon for getting started:

{{< youtube OozklZXFbDQ >}}


## Credit

Much credit goes to [github.com/itzg](https://github.com/itzg) for his [docker-minecraft-server](https://github.com/itzg/docker-minecraft-server) project.

## Thank You

Thanks for reading, if you like my content, check out my **[website](https://ruan.dev)** or follow me at **[@ruanbekker](https://twitter.com/ruanbekker)** on Twitter.
