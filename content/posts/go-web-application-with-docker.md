---
title: "Go Web Application using Docker"
date: 2021-04-23T23:43:54+02:00
draft: false
description: "Tutorial on how to dockerize a golang web application and running the binary from a scratch image to optimize storage size."
tags: ["docker", "containers", "golang"]
categories: ["containers"]
---

In this tutorial we will be building a go based application using docker and make use of multi-stage builds so that we can optimize our storage size of our image. The source code can be found on [github](https://github.com/ruanbekker/go-hostname)

## Go Application

Our go application is a simple web application that returns the hostname. This can also be a useful application if you run it with orchestrators such as Kubernetes or Docker Swarm, when using more than 1 replicas on multiple nodes, as when the application is scaled each container will respond with different hostnames.

The application code:

```go
package main

import (
    "fmt"
    "os"
    "net/http"
)

func hostnameHandler(w http.ResponseWriter, r *http.Request) {
    myhostname, _ := os.Hostname()
    fmt.Fprintln(w, "Hostname:", myhostname)
}

func main() {
    const port string = "8000"
    fmt.Println("Server listening on port", port)
    http.HandleFunc("/", hostnameHandler)
    http.ListenAndServe(":" + port, nil)
}
```

## Docker

In our dockerfile, you will see that we are using multi-stage builds as our target will only require the built binary which runs on the scratch image, which makes our container image super small:

```dockerfile
FROM golang:alpine AS builder
WORKDIR /go/src/hello
RUN apk add --no-cache gcc libc-dev
ADD app.go /go/src/hello/app.go
RUN GOOS=linux GOARCH=amd64 go build -tags=netgo app.go

FROM scratch
COPY --from=builder /go/src/hello/app /app
CMD ["/app"]
```

So essentially we are using the `golang:alpine` image as our build environment, installing required packages for our build, then we are adding our `app.go` file from our host to the container runtime, the we are building the go binary. Once that is done, we are using a new upstream image and copying the built binary from our build environment to the target runtime and adding the path to the binary as `CMD` so that it runs the binary when a container is created from the image.

To build our container image:

```bash
docker build -t mycontainerimage:v1 .
```

Now that our container image has been built, lets run a container from our container image and expose port 8000 from our host and map it to the container port of 8000 which the application is listening on:

```bash
docker run -it -p 8000:8000 mycontainerimage:v1
Server listening on port 8000
```

## Test the Application

Now that our container is running, make a http request using curl:

```bash
curl http://localhost:8000
Hostname: d677c0022240
```

## Source Code

The source code for this application can be found on:
- https://github.com/ruanbekker/go-hostname

The container image is also hosted on Docker Hub with the name `ruanbekker/hostname` and can be checked out here:
- https://hub.docker.com/r/ruanbekker/hostname


