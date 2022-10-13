---
title: "How to create ARM based images using Buildx"
date: 2022-10-13T06:00:00+02:00
draft: false
description: "This tutorial will demonstrate how to create ARM based images using Buildx using Docker"
tags: ["docker", "buildx", "arm"]
categories: ["containers"]
---

This is a short post on how to create container images with docker and buildx so that it’s compatible with ARM architectures such as the Apple M1 and Raspberry Pi 64 bit.

## Dockerfile

We will have a simple dockerfile that runs from a alpine image and we will be installing curl:

```
FROM alpine:latest
LABEL maintainer "Ruan Bekker"
RUN apk --no-cache add curl
```

## Buildx

List your current builder instances:

```
$ docker buildx ls
NAME/NODE        DRIVER/ENDPOINT             STATUS   PLATFORMS
default                  docker default                     running    linux/amd64, linux/386
```

As you can see we only have amd64 and i386 architecture support for when we build container images.

Create a build instance that supports arm64 and arm:

```bash
$ docker buildx create --name multi-arch \
  --platform "linux/arm64,linux/amd64,linux/arm/v7" \
  --driver "docker-container"
```

Now we can update our default builder instance:

```bash
$ docker buildx use multi-arch
```

## Build and Push

If you want to push to your image registry (using an assumption its docker hub):

```bash
$ docker login
```

Now we can build and push our container image with multi-arch support to our image registry:

```
$ docker buildx build \
  --platform "linux/amd64,linux/arm64,linux/arm/v7" \
  --tag ruanbekker/curl:test \
  --push .
```

When you head over to my dockerhub repository:

- https://hub.docker.com/r/ruanbekker/containers/tags

You will see the digests for each architecture that we included:

![image](https://user-images.githubusercontent.com/567298/195526699-158dc17c-6d2a-46ce-8444-54419400fcf7.png)

## Test on Apple M1

If we test this by running a container from our container image on a Apple M1, we will see that it will use the correct digest hash:

```bash
$ docker run -it ruanbekker/curl:test sh
Unable to find image 'ruanbekker/curl:test' locally
test: Pulling from ruanbekker/curl
9b18e9b68314: Already exists
5f2095374d74: Pull complete
Digest: sha256:5d87f95ded0e7e057152f8c32d4b0b81a1e2415f2b6a2ec2ac53dd8cbbc4ab39
Status: Downloaded newer image for ruanbekker/curl:test
/ # curl
curl: try 'curl --help' or 'curl --manual' for more information
```

## Thank You

Thanks for reading, if you like my content, check out my **[website](https://ruan.dev)** or follow me at **[@ruanbekker](https://twitter.com/ruanbekker)** on Twitter.
