---
title: "Run Docker Containers"
date: 2021-04-05T23:43:54+02:00
draft: false
description: "Tutorial on building container images and running docker containers."
tags: ["docker", "containers"]
categories: ["containers"]
---

In this tutorial we will demonstrate how to build a container image and how to run a docker container, as well as how to persist data and exposing host ports to reach the container ports.

## Assumptions

I will assume that you have [docker](https://docs.docker.com/get-docker/) installed.

## Running a Container

Let's start with the basics, running a container. To run a container, we instantiate a container instance from a container image. There are thousands of container images on a container registry such as [docker hub](https://hub.docker.com), a example that we will be working with will be the ubuntu official image.

In the following command:

```bash
docker run -it ubuntu:latest bash
```

We are running a container from the ubuntu image, and we are using the latest version by specifying the image with it's tag: `ubuntu:latest`, we are also specifying that we want to attach the bash shell to a interactive shell with `-it` which is short for `--interactive --tty`.

Once we run our command we will be placed inside the container, then we run the `hostname` command to see the containers hostname:

```bash
docker run -it ubuntu:latest bash
# hostname
0e7af919daa5
```

Because we attached the `bash` shell to our session our container is running while we are inside the container, as soon as we exit the container, the container will be stopped and not be in a running state anymore. We can verify the behaviour by running `docker ps -l` to see the info of the last running container:

```bash
# exit
docker ps -l
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS                     PORTS               NAMES
0e7af919daa5        ubuntu:latest       "bash"              54 seconds ago      Exited (0) 8 seconds ago                       stoic_bhabha
```

As you can see the container id matches the hostname, and that will always be the default behaviour of a container.

## Running a Container in the Background

If the image we want to run a container from, does not have a process that allows the container to remain running, we can specify the command, something like `sleep 120` and run the container in detached mode. We will also name the container with `--name detached-container` and once we run a container with a specific name, and we want to run it again, it will error due to the container name already exists, therefore we will pass the flag `--rm` so it deletes the container on exit, so we dont have to manually do it:

```bash
docker run --rm -itd --name detached-container ubuntu:latest sleep 120
131f7e78903c6b8d40989148a4ec0f04f9def9db997564c56fdba897dec5df80
```

Now because we ran the container in detached mode, which is the `-d` in `-itd`, we can verify that the container is running, by using `ps` and specifying a name filter:

```bash
docker ps -f name=detached-container
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
131f7e78903c        ubuntu:latest       "sleep 120"         2 seconds ago       Up 2 seconds                            detached-container
```

Because we specified the command as `sleep 120` the container will only be running for 120 seconds, then it will exit. So let's run the container again and specify a larger number to keep it running for longer:

```bash
docker run --rm -itd --name detached-container ubuntu:latest sleep 600
```

Now since its running, we can `exec` into the container, we can either exec using the container name `--name` or by specifying the container id. Let's exec using the container id, therefore we need to get the id first:

```bash
docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED              STATUS              PORTS               NAMES
f243d803cbd8        ubuntu:latest       "sleep 600"         About a minute ago   Up About a minute                       detached-container
```

Now we can exec into the container by passing the container id:

```bash
docker exec -it f243d803cbd8 bash
```

Now we are placed inside the container, and we can use `ps` and you will notice the sleep command is currently running:

```bash
root@f243d803cbd8:/# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0   2516   592 pts/0    Ss+  22:14   0:00 sleep 600
root           6  1.0  0.0   4116  3584 pts/1    Ss   22:17   0:00 bash
root          14  0.0  0.0   5904  3096 pts/1    R+   22:17   0:00 ps aux
```

Once you `exit` from the container, you can similarly exec into the container by specifying the name that you provided for the container:

```bash
docker exec -it detached-container bash
```

## Container Persistence

Containers are stateless by design, so if you run a container and write data to the containers filesystem and you exit, that data is lost. Technically you can revive the data by starting the stopped container and commit the container id to the image, but it feels like a hack to me, and I treat the containers ephemeral.

A way to persist the data is by using volumes, or in the docker run commoand it will be with `-v` which you will map the host's filesystem path to the containers filesystem path. 

So let's say you want to persist data in the containers path under `/data`, you will map the host path, lets say `/Users/ruan/data` to the containers path `/data`, so when you write content inside the container in `/data` the data gets written on `/Users/ruan/data` on the host, so when you exit the container and run another container with the same volume mapping, the data will be persisted.

Let's run a container with the mentioned volume mappings:

```bash
docker run --rm -it -v /Users/ruan/data:/data ubuntu bash
```

Once we are inside the container, write data to the persisted location `/data` and write data to a location that is not persisted, like `/tmp`, then exit the container:

```bash
root@1fd34a6e57d7:/# echo "hi" > /data/test1.txt
root@1fd34a6e57d7:/# echo "hi" > /tmp/test2.txt
root@1fd34a6e57d7:/# exit
```

Now run a new container with the same volume mappings, and you should see the persisted directory's data is persisted:

```bash
docker run --rm -it -v /tmp/data:/data ubuntu bash
root@193d7f987a32:/# cat /data/test1.txt
hi
```

And the non-persisted location is not accessible:

```bash
root@193d7f987a32:/# cat /tmp/test2.txt
cat: /tmp/test2.txt: No such file or directory
````

When we `exit` the container, we can see that the file is present on our host's filesystem:

```bash
cat /Users/ruan/data/test1.txt
hi
```

You get different [docker storage drivers](https://docs.docker.com/storage/storagedriver/select-storage-driver/) which can make use of cloud block storage such as EBS, etc.

## Exposing a Port

So let's say you browsed on [docker hub](https://hub.docker.com/_/nginx) and found the [nginx](https://hub.docker.com/_/nginx) docker image, and you would like to run the container and access the nginx container port which will be port `80`, from the host which is running docker. 

We will be making use of exposed ports, which is referenced with `-p`, you will bind the host port that you are connecting to, to the container port. So let's say you want to access the Nginx container from your workstation on `http://localhost:80` to traverse to the container port on `80`, your configuration will look like `-p 80:80`.

But in this case port 80 is already running on my laptop, so we will open port 8080 to connect to the container on port 80:

```bash
docker run --rm -it -p 8080:80 nginx:latest
```

Now we can access the nginx container from our host on port `80`, because the container is running in the foreground, I will open a new terminal tab, and use curl to test the connectivity:

```bash
curl -I http://localhost:8080/
HTTP/1.1 200 OK
Server: nginx/1.19.9
Date: Mon, 05 Apr 2021 22:41:00 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 30 Mar 2021 14:47:11 GMT
Connection: keep-alive
ETag: "606339ef-264"
Accept-Ranges: bytes
```

And on the terminal where we ran the docker command, we can see the logs:

```
172.17.0.1 - - [05/Apr/2021:22:41:00 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.68.0" "-"
```

## Building a Docker Image

So let's say you want to run a slim base image, such as [alpine](https://hub.docker.com/_/alpine), but you want to add files to the container or install packages, it's not really practical to run the container and install packages, because when you exit your container you will lose your changes.

The answer is to build a docker image to the desired state of how you want to package up your container, then you can reuse it as many times as possible.

In this example we will build a basic container that just runs a bash command on the startup when we run the container, we first need to create a `Dockerfile` which acts as the file with the instructions on how the container image will be built:

```dockerfile
# we are using the alpine base image as a starting point
FROM alpine:latest

# install bash
RUN apk --no-cache add bash

# copy the bash script
COPY run.sh /bin/run.sh

# this will run when the container runs
CMD ["/bin/bash", "/bin/run.sh"]
```

Create the `run.sh` bash script:

```bash
echo "hello, world!"
```

Build the container image with the tag `myfirstcontainerimage:v1`:

```bash
docker build -f ./Dockerfile -t myfirstcontainerimage:v1 .
```

Im the above command if the `Dockerfile` is in the current working directory, you don't need to specify the `Dockerfile` as it will expect it as that as default, then we specify the tag we build the container image as, and we specify the context directory where it should build from with `.` which is the current directory.

Once our image has been built we can verify by running:

```bash
docker images
REPOSITORY                        TAG                 IMAGE ID            CREATED             SIZE
myfirstcontainerimage             v1                  31eb211e6355        4 seconds ago       7.76MB
```

As we can see our container image that exists on our local workstation is only 7.76MB small. 

(Optional): If you sign up with docker hub, you can then log in with your credentials `docker login` and push this image to the public container registry, but then when you build the image, you will tag it as the username and repo that you have on docker hub, as example: `-t myusername/myrepo:v1` and then push with `docker push myusername/myrepo:v1`.

Run a container from the built container image:

```bash
docker run -it myfirstcontainerimage:v1
hello, world!
```

## Thank You

Containers are amazing, and you can speed up the process to get your environment running in no time, to find more docker images head over to:
- https://hub.docker.com

And for most of the images, they are either documented on the page, or on their github repository.
