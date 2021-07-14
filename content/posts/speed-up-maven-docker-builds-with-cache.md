---
title: "Speed up Maven Docker builds with Cache"
date: 2021-07-15T07:00:00+02:00
draft: false
description: "Tutorial on how to speed up your java and maven based docker builds using cache volumes using buildkit."
tags: ["docker", "java", "maven", "performance"]
categories: ["containers"]
---

This post will demonstrate how to speed up your maven builds using docker and buildkit as long as the docker build on the same docker host.

## Layer Caching

With docker we know that order matters in a dockerfile, as each layer is cached, and therefore to optimise a dockerfile we set the dockerfile from least changes to most changes, as this example:

```dockerfile
FROM maven:3.6.3-openjdk-15
COPY . /app
RUN mvn clean package
ARG JAR_FILE=/app/target/*.jar
RUN mv $JAR_FILE /app/app.jar
CMD ["java", "-jar", "/app/app.jar"]
```

Every step is cached onto a layer, so if docker completes building an image, and we insert a line between 1 and 2 then the layer cache from those steps gets invalidated and has to run the following steps from the new layers.

## Persistence

Due to source code changing all the time, maven pulls down dependencies to the `~/.m2` directory inside the container, as by design docker is stateless and the directory is not persisted, and on build time, the directory is empty, which contributes to the lengthy build time.

The first build:

```bash
docker build -t test:v1 .
[+] Building 221.7s (15/15) FINISHED
```

The second build, I changed my source code, which now needs to run step 2 again:

```bash
docker build -t test:v2 .
[+] Building 202.2s (15/15) FINISHED
```

We can see its a little bit faster as the base image was cached.

## Caching with Buildkit

As a workaround to this, you can use a mounted volume on the host to the build container on the container path `~/.m2` but this method can cause disk full errors during build time and the shared folder could become owned by root, which is a bit messy and has its disadvantages.

[Buildkit](https://docs.docker.com/develop/develop-images/build_enhancements/) was introduced from Docker 18.09 and has a lot of enhancements and build time improvements are one of them, as it builds a graph on dependencies and figures out which steps to run together in paralel.

Buildkit extends the `RUN` command with `--mount` which we can use to cache the `~/.m2` container directory to the docker host, which can be used and shared by multiple projects.

## Invalidating the Cache

And since docker manages this mount, it can be pruned as well with:

```bash
docker builder prune --filter type=exec.cachemount
```

## Caching Example

Let’s take this multistage dockerfile as an example:

- we introduce a cache mount to the target where the dependencies will reside
- use multistage builds with just a jre and copy the jar from our builder image

A note on multistage builds, this helps reducing the docker image size, which reduces the time to pull down a image and run a container where theres no image cache available on that host.

The size difference on multistage builds:

```bash
docker images | grep -E '(REPOSITORY|maven|adoptopenjdk|singlestage|multistage)'
REPOSITORY                       TAG                       IMAGE ID       CREATED              SIZE
singlestage                      v1                        bf9d9f0a9ad2   About a minute ago   777MB
multistage                       v1                        cd2965b2b2a9   56 minutes ago       306MB
adoptopenjdk                     11-jre-hotspot            3f88e14a3a92   3 weeks ago          244MB
maven                            3.6.1-amazoncorretto-11   11f98c0d04f4   22 months ago        659MB
```

If you want to follow along, you can use the example **java application** in my [github repository](https://github.com/ruanbekker/docker-java-springboot-hello-world), the **multistage dockerfile**:

```dockerfile
FROM maven:3.6.3-openjdk-15 as builder
WORKDIR /app
COPY . /app
RUN --mount=type=cache,target=/root/.m2 mvn -f /app/pom.xml clean package

FROM adoptopenjdk:15-jre-hotspot
ARG JAR_FILE=/app/target/*.jar
WORKDIR /app
COPY --from=builder $JAR_FILE /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

On the fist build:

```bash
docker build -t cachetest:v1 .
[+] Building 221.7s (15/15) FINISHED
```

Now let’s add something on the second line, to force docker to run the steps after that again:

```bash
FROM maven:3.6.3-openjdk-15 as builder
RUN echo hi
WORKDIR /app
COPY . /app
RUN --mount=type=cache,target=/root/.m2 mvn -f /app/pom.xml clean package
...
```

Now let’s run the build again:

```bash
docker build -t cachetest:v2 .
[+] Building 8.5s (16/16) FINISHED
```

And as you can see buildkit improved the docker build speed from **221.7s** to **8.5s**.

## Thank You

Thanks for reading, if you like my content, check out my **[website](https://ruan.dev)** or follow me at **[@ruanbekker](https://twitter.com/ruanbekker)** on Twitter.
