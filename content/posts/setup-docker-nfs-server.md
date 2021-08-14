---
title: "Setup Docker NFS Server"
date: 2021-08-14T12:00:00+02:00
draft: false
description: "Tutorial on how to setup a NFS Server on Docker."
tags: ["docker", "nfs", "server"]
categories: ["containers"]
---

In this post we will see how quick and fast it is to setup a **NFS Server** using a **Docker** container using the [itsthenetwork/nfs-server-alpine](https://hub.docker.com/r/itsthenetwork/nfs-server-alpine) image.

If you would like to install **NFS Server** using a non-docker based deployment, you can have a look at [installing nfs server on ubuntu](https://sysadmins.co.za/setup-a-nfs-server-on-ubuntu/).

## Overview

On our host we will use the local path: `/data/docker-volumes` to mount inside the container to `/data` and expose the port `2049` from the container to the host.

## Getting Started

I'm assuming that you have [docker](https://docs.docker.com/get-docker/) and [docker-compose](https://docs.docker.com/compose/install/) installed.

Create the local directory:

```
$ mkdir -p /data/docker-volumes
```

Next, create the `docker-compose.yml`

```yaml
version: "3.8"
services:
  # https://hub.docker.com/r/itsthenetwork/nfs-server-alpine
  nfs:
    image: itsthenetwork/nfs-server-alpine:12
    container_name: nfs
    restart: unless-stopped
    privileged: true
    environment:
      - SHARED_DIRECTORY=/data
    volumes:
      - /data/docker-volumes:/data
    ports:
      - 2049:2049
```

Boot the container:

```bash
$ docker-compose up -d
```

## Testing NFS

To test our NFS Server, let's install the NFS client to our host:

```bash
$ sudo apt install nfs-client -y
```

Now let's mount our NFS mount to our local path: /mnt:

```bash
$ sudo mount -v -o vers=4,loud 192.168.0.4:/ /mnt
```

Verify that the mount is showing:

```bash
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda2       109G   53G   51G  52% /
192.168.0.4:/   4.5T  2.2T  2.1T  51% /mnt
```

Now, create a test file on our NFS export:

```bash
$ touch /mnt/file.txt
```

Verify that the test file is on the local path:

```bash
$ ls /data/docker-volumes/
file.txt
```

## Persistent Mount

If you want to load this into other client's `/etc/fstab`:

```bash
192.168.0.4:/   /mnt   nfs4    _netdev,auto  0  0
```

## Thank You

Thanks for reading, if you like my content, check out my **[website](https://ruan.dev)** or follow me at **[@ruanbekker](https://twitter.com/ruanbekker)** on Twitter.
