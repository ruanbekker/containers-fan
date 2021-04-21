---
title: "Why you should use Multi Stage Docker Builds"
date: 2021-04-21T20:43:54+02:00
draft: false
description: "Tutorial on building slim docker images using multstage docker builds."
tags: ["docker", "containers", "go"]
categories: ["containers"]
---

In this tutorial I will demonstrate how to build slim docker images using multistage docker builds, where you can save up to 800MB of disk space per image.

## About

We will use multistage docker builds from a alpine image as our build image to get the dependencies, build the go binary and use our scratch image to place the built binary onto our target image to have small docker images.

## Why does size matter

So let's assume you have a orchestrator such as ECS, Swarm or Kubernetes with 100 nodes behind a Auto Scaling Group, where your cluster node count is 10 when theres low traffic, and 100 nodes when theres lots of traffic.

As we scale out our service might scale from 10 replicas to 500 replicas and let's assume our container image is 800MB in size, when a new node joins a cluster the container image won't be in the cache so the docker daemon needs to download that image from the docker registry. So let's say 100 nodes join the cluster and our service scales to 100 replicas, it means that each node needs to download 800MB from the docker registry, that is about 80GB of incoming network throughput to the cluster.

So when we use multistage builds and in this case using Go, we can slim down our container image to less than 3MB, if we do the same calculation, that is just less than 300MB of throughput and if a fresh node joins a cluster and the container image is not present, it will take about a second or two to download and getting the container to run (depending on internet speed) and you obviously save disk space.

## Go Application

We will use a library that generates random data from [go-randomdata](https://github.com/Pallinder/go-randomdata) in our application, `app.go`:

```go
package main

import (
    "fmt"
    "github.com/Pallinder/go-randomdata"
)

func main() {
    profile := randomdata.GenerateProfile(randomdata.Male | randomdata.Female | randomdata.RandomGender)
    fmt.Printf("The new profile's username is: %s and password (md5): %s\n", profile.Login.Username, profile.Login.Md5)
}
```

## Single Stage Docker Build

In this example we will use the golang image to get the dependencies and build the application in one image, our `Dockerfile.single_stage`:

```dockerfile
FROM golang:latest as builder
RUN mkdir -p /go/src/github.com/ruanbekker
WORKDIR /go/src/github.com/ruanbekker
RUN useradd -u 10001 app
COPY . .
ENV GO111MODULE=auto
RUN go get
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .
USER app
CMD ["/go/src/github.com/ruanbekker/main"]
```

Building the image:

```bash
docker build -f Dockerfile.single_stage -t goapp:singlestage .
```

## Multi Stage Docker Build

Our multi stage consist of a build image where we will use the golang image to fetch our dependencies and build our application, then we use the scratch image as the target to copy the compiled binary to and run the container from the slim image, our `Dockerfile.multi_stage`:

```dockerfile
FROM golang:latest as builder
RUN mkdir -p /go/src/github.com/ruanbekker
WORKDIR /go/src/github.com/ruanbekker
RUN useradd -u 10001 app
COPY . .
ENV GO111MODULE=auto
RUN go get
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

FROM scratch
COPY --from=builder /go/src/github.com/ruanbekker/main /main
COPY --from=builder /etc/passwd /etc/passwd
USER app
CMD ["/main"]
```

Building the image:

```bash
docker build -f Dockerfile.multi_stage -t goapp:multistage .
```

## Comparing the size differences

When we compare the size differences of our docker images between a normal build and a multi-stage build we can see a huge difference:

```bash
docker images | head -3
REPOSITORY                        TAG                 IMAGE ID            CREATED             SIZE
goapp                             singlestage         0d0c1f4c98a2        54 seconds ago      896MB
goapp                             multistage          d74ac27a39c8        2 hours ago         2.75MB
```

And just to show that both containers run from the built docker images, our single build:

```bash
docker run -it goapp:singlestage
The new profile's username is: Maregrass and password (md5): 56da7705b7648a38f539b043e6a494be
```

And our multi-stage build:

```
docker run -it goapp:multistage
The new profile's username is: Shirtplaid and password (md5): 7d8606ee86f2da3ed12c595ab617bf4e
```

## Thank You

If you liked this content, please make sure to share or come say hi on my website or twitter:

  * **Website**: [ruan.dev](https://ruan.dev)
  * **Twitter**: [@ruanbekker](https://twitter.com/ruanbekker)
