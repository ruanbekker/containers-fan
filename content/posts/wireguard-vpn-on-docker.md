---
title: "Setup Wireguard VPN on Docker"
date: 2021-06-08T04:00:00+02:00
draft: false
description: "Tutorial on how to setup a wireguard vpn on docker and setup your wireguard vpn clients to access your private network in a secure way."
tags: ["docker", "wireguard", "vpn", "networking"]
categories: ["containers"]
---

In this tutorial, I will demonstrate how to setup a Secure VPN using [Wireguard](https://www.wireguard.com/) on [Docker](https://www.docker.com/) using docker-compose and then we will use a Windows PC to connect to our Wireguard VPN using the Wireguard Client to access our Private Network in a secure way.

## Wireguard Configuration

The following configurations should be changed, depending on your setup:
- `TZ` - timezone
- `SERVERURL` - this will be set where your client will connect to
- `SERVERPORT` - this will be set in your client config (the listen port is hardcoded to 51820)
- `PEERDNS` - this is the dns server that will be set in the client config (I use [PiHole](https://pi-hole.net/) for DNS to block ads)
- `PEERS` - this is used to create configs for your clients
- `INTERNAL_SUBNET` - this is optional, but this is the subnet the connected clients will use

## Start the Wireguard Server

The content of our docker-compose.yml :

```
version: '3.7'

services:

  wireguard:
    image: ghcr.io/linuxserver/wireguard
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Africa/Johannesburg
      - SERVERURL=wireguard.example.com
      - SERVERPORT=51820
      - PEERS=ruan,mobile
      - PEERDNS=192.168.0.114 
      - INTERNAL_SUBNET=10.64.1.0
      - ALLOWEDIPS=0.0.0.0/0
    volumes:
      -  ./config/wireguard:/config
      - /lib/modules:/lib/modules
    ports:
      - 51820:51820/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
```

Start up wireguard using docker compose:

```
$ docker-compose up -d
```

Once wireguard has been started, you will be able to tail the logs to see the initial qr codes for your clients, but you have access to them on the config directory:

```
$ docker-compose logs -f wireguard
```

The config directory will have the config and qr codes as mentioned:

```
$ ls ./config/wireguard/peer_ruan
peer_ruan.conf  peer_ruan.png  privatekey-peer_ruan  publickey-peer_ruan
```

## Install the Wireguard Client

Head over to https://www.wireguard.com/install/ and install the client of your operating system, I will be using Windows in this example to demonstrate the setup.

I have a couple of configured tunnels already, but yours should looks something like this:

![image](https://user-images.githubusercontent.com/567298/121121580-20d0de00-c820-11eb-8728-86e14c29b4b0.png)

To setup a new tunnel, from the new tunnel options select add empty tunnel:

![image](https://user-images.githubusercontent.com/567298/121121680-54ac0380-c820-11eb-93db-b4b819d974ba.png)

Copy the content from your config directory, for demonstration I will show you how one of my peer configs looks like:

```
$ cat ./config/wireguard/peer_ruan/peer_ruan.conf
[Interface]
Address = 10.64.1.2
PrivateKey = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ListenPort = 51820
DNS = 192.168.0.114

[Peer]
PublicKey = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Endpoint = xxxxx.xxxxx.xxx:51820
AllowedIPs = 0.0.0.0/0
```

Then paste the config content and name your tunnel:

![image](https://user-images.githubusercontent.com/567298/121121985-ea479300-c820-11eb-9d72-5f82c5d8f1d9.png)

## Connect the Wireguard VPN

Once you connected the VPN you should see something like this:

![image](https://user-images.githubusercontent.com/567298/121122635-1a436600-c822-11eb-9142-d13ec1d4d132.png)

Now the connected client should be able to access the private network over the VPN where Wireguard is running.

## Thank You

Thanks for reading, if you like my content, check out my **[website](https://ruan.dev)** or follow me at **[@ruanbekker](https://twitter.com/ruanbekker)** on Twitter.
