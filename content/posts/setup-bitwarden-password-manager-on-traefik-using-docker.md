
---
title: "Setup Bitwarden Pasword Manager on Docker with Traefik"
date: 2021-06-23T06:00:00+02:00
draft: false
description: "Learn how to setup a open source password manager called bitwarden on docker and use traefik as our http proxy with letsencrypt ssl traefik from secure communication"
tags: ["docker", "containers", "traefik", "bitwarden", "security"]
categories: ["containers"]
---

Today we will setup **Bitwarden** and **Traefik** on Docker using Docker Compose. We will make use of **Letsencrypt** for our SSL Certificates so that our communcation from the clients and server is secure and then we will install the **Bitwarden Firefox browser extension** to save our passwords for our web applications on Bitwarden password manager.

## What is Bitwarden

![bitwarden-image](https://user-images.githubusercontent.com/567298/123048483-be223980-d3fe-11eb-8eda-845b16556611.png)

Bitwarden is open source password manager, similar to Last Pass and makes it super easy to generate and store unique passwords for any browser or device. You own the data as it's self hosted, which is a plus for security, but always keep in mind to keep your local content safe and secure. Please check out [their website](https://bitwarden.com/) to find out more about them.

## What is Traefik

![traefik-image](https://user-images.githubusercontent.com/567298/123048606-de51f880-d3fe-11eb-9f28-350ffa0922ec.png)

Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices super easy by making use of docker labels to route your traffic based on host headers, path prefixes etc. Please check out [their website](https://doc.traefik.io/traefik/) to find out more about them.

## DNS

In my case I have created DNS Entries which points to the public ip of my test instance of my docker host.

```
traefik.rbkr.xyz
bitwarden.rbkr.xyz
```

## Pre-Requisites

You will need docker and docker-compose to be installed, if you don't have it installed you can follow [their documentation](https://docs.docker.com/get-docker/) but in my case the setup involved:

```bash
curl https://get.docker.com | bash
sudo usermod -aG docker $USER
sudo curl -L "https://github.com/docker/compose/releases/download/1.28.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

## Setting up Bitwarden and Traefik

In our `docker-compose.yml` file we will define our **traefik** and **bitwarden** services. If you are following along, please make sure to replace the domain used: *rbkr.xyz* with your domain:

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:2.4
    container_name: traefik
    restart: unless-stopped
    volumes:
      - ./traefik/acme.json:/acme.json
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - docknet
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.api.rule=Host(`traefik.rbkr.xyz`)'
      - 'traefik.http.routers.api.entrypoints=https'
      - 'traefik.http.routers.api.service=api@internal'
      - 'traefik.http.routers.api.tls=true'
      - 'traefik.http.routers.api.tls.certresolver=letsencrypt'
    ports:
      - 80:80
      - 443:443
    command:
      - '--api'
      - '--providers.docker=true'
      - '--providers.docker.exposedByDefault=false'
      - '--entrypoints.http=true'
      - '--entrypoints.http.address=:80'
      - '--entrypoints.http.http.redirections.entrypoint.to=https'
      - '--entrypoints.http.http.redirections.entrypoint.scheme=https'
      - '--entrypoints.https=true'
      - '--entrypoints.https.address=:443'
      - '--certificatesResolvers.letsencrypt.acme.email=ruan@ruanbekker.com'
      - '--certificatesResolvers.letsencrypt.acme.storage=acme.json'
      - '--certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=http'
      - '--log=true'
      - '--log.level=INFO'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  bitwarden-frontend:
    image: nginx:1.15-alpine
    container_name: bitwarden-frontend
    restart: unless-stopped
    volumes:
      - ./bitwarden/frontend/bitwarden.conf:/etc/nginx/conf.d/bitwarden.conf
    networks:
      - docknet
    depends_on:
      - bitwarden-backend
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.bitwarden.rule=Host(`bitwarden.rbkr.xyz`)'
      - 'traefik.http.routers.bitwarden.entrypoints=https'
      - 'traefik.http.routers.bitwarden.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.bitwarden.service=bitwarden-service'
      - 'traefik.http.services.bitwarden-service.loadbalancer.server.port=80'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  bitwarden-backend:
    image: vaultwarden/server:latest
    container_name: bitwarden-backend
    restart: unless-stopped
    volumes:
      - ./bitwarden/backend/data:/data
    environment:
      - WEBSOCKET_ENABLED=true
    networks:
      - docknet
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  bitwarden-backup:
    image: bruceforce/bw_backup:latest
    container_name: bitwarden-backup
    restart: unless-stopped
    depends_on:
      - bitwarden-backend
    volumes:
      - ./bitwarden/backend/data:/data
      - ./bitwarden/backend/backup:/backup
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    environment:
      - DB_FILE=/data/db.sqlite3
      - BACKUP_FILE=/backup/backup.sqlite3
      - CRON_TIME=0 1 * * *
      - TIMESTAMP=false
      - UID=0
      - GID=0
    networks:
      - docknet
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

networks:
  docknet:
    name: docknet
```

Our `./bitwarden/frontend/bitwarden.conf` for nginx which includes reverse proxy connections to the bitwarden containers as well as websockets as you can see in the http_upgrade headers:

```
server {
    listen         80;
    server_name    bitwarden.rbkr.xyz;
    client_max_body_size 128M;

    location / {
        proxy_pass http://bitwarden-backend:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /notifications/hub {
        proxy_pass http://bitwarden-backend:3012;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /notifications/hub/negotiate {
        proxy_pass http://bitwarden-backend:80;
    }
}
```

Traefik will persist the letsencrypt data in a file called `acme.json` which requires specific permissions, therefore prepare the `./traefik/acme.json` file beforehand:

```bash
mkdir traefik
touch traefik/acme.json
chmod 600 traefik/acme.json
```

Then pull the docker images down:

```bash
docker-compose pull

Pulling traefik            ... done
Pulling bitwarden-backend  ... done
Pulling bitwarden-frontend ... done
Pulling bitwarden-backup   ... done
```

Then start the containers up, and look at the logs if you are seeing more or less the following lines:

logs:

```
docker-compose -f docker-compose.yml up

Creating network "docknet" with the default driver
Creating bitwarden-backend ... done
Creating traefik            ... done
Creating bitwarden-backup   ... done
Creating bitwarden-frontend ... done
Attaching to bitwarden-backend, traefik, bitwarden-frontend, bitwarden-backup
bitwarden-backend     | [2021-06-22 06:39:41.720][start][INFO] Rocket has launched from http://0.0.0.0:80
bitwarden-backend     | [2021-06-22 06:39:41.720][parity_ws][INFO] Listening for new connections on 0.0.0.0:3012.
traefik               | time="2021-06-22T06:39:41Z" level=info msg="Configuration loaded from flags."
traefik               | time="2021-06-22T06:39:41Z" level=info msg="Traefik version 2.4.8 built on 2021-03-23T15:48:39Z"
traefik               | time="2021-06-22T06:39:41Z" level=info msg="Starting provider aggregator.ProviderAggregator {}"
traefik               | time="2021-06-22T06:39:41Z" level=info msg="Starting provider *traefik.Provider {}"
traefik               | time="2021-06-22T06:39:41Z" level=info msg="Starting provider *acme.ChallengeTLSALPN {\"Timeout\":4000000000}"
traefik               | time="2021-06-22T06:39:41Z" level=info msg="Starting provider *acme.Provider {\"email\":\"x@x.com\",\"caServer\":\"https://acme-v02.api.letsencrypt.org/directory\",\"storage\":\"acme.json\",\"keyType\":\"RSA4096\",\"httpChallenge\":{\"entryPoint\":\"http\"},\"ResolverName\":\"letsencrypt\",\"store\":{},\"TLSChallengeProvider\":{\"Timeout\":4000000000},\"HTTPChallengeProvider\":{}}"
traefik               | time="2021-06-22T06:39:41Z" level=info msg="Testing certificate renew..." providerName=letsencrypt.acme
traefik               | time="2021-06-22T06:39:43Z" level=info msg="Skipping same configuration" providerName=docker
traefik               | time="2021-06-22T06:39:47Z" level=info msg=Register... providerName=letsencrypt.acme
```

If you want to detach the containers, you can run:

```bash
docker-compose -f docker-compose.yml up -d
```

When we access `http://traefik.rbkr.xyz` it should redirect you to `https://traefik.rbkr.xyz` with `rbkr.xyz` being my domain in this case, and you should see Traefik's pretty dashboard:

![image](https://user-images.githubusercontent.com/567298/122876604-fe69b500-d335-11eb-8c48-042b8cb8cae3.png)

We can also verify that the certificate is valid:

![image](https://user-images.githubusercontent.com/567298/122876822-3a9d1580-d336-11eb-9201-98dbd39c6dad.png)

When we access `https://bitwarden.rbkr.xyz` you should see the following screen:

![image](https://user-images.githubusercontent.com/567298/122876932-5b656b00-d336-11eb-8ffa-bbdbf41a119e.png)

Select create account:

![image](https://user-images.githubusercontent.com/567298/122877270-b72ff400-d336-11eb-9b15-8dbbd8964a18.png)

Then set your master password, ensure this is a strong password and once you registered your account, log in and you should see the following:

![image](https://user-images.githubusercontent.com/567298/122877480-efcfcd80-d336-11eb-9def-b692417c6168.png)

To manually create a entry for a website with a username and password:

![image](https://user-images.githubusercontent.com/567298/122877964-7d132200-d337-11eb-92cb-9279fc6f0287.png)

Below the generate password icon is a icon to preview the generated password:

![image](https://user-images.githubusercontent.com/567298/122878081-9b791d80-d337-11eb-833c-ee2a64687d01.png)

Once you save the item it will appear in your vault:

![image](https://user-images.githubusercontent.com/567298/122878188-bea3cd00-d337-11eb-81ee-a62ca126ec5f.png)

## Browser Extension

In this example I will be using Firefox to install the Bitwarden Browser Extension:
- https://addons.mozilla.org/en-US/firefox/addon/bitwarden-password-manager/

Which should look like this:

![image](https://user-images.githubusercontent.com/567298/122878495-1c381980-d338-11eb-888b-32717a8ae117.png)

Select "Add to Firefox" and a new tab will open to ask you to log in, but we need to set our server details, so select the bitwarden extension button on the right:

![image](https://user-images.githubusercontent.com/567298/122878719-59041080-d338-11eb-9ad4-350cc920966a.png)

Then hit settings and set your bitwarden url, and save:

![image](https://user-images.githubusercontent.com/567298/122879000-ac765e80-d338-11eb-9822-3b88284fa111.png)

Then you can login and you should see the entry from earlier:

![image](https://user-images.githubusercontent.com/567298/122879195-ecd5dc80-d338-11eb-868a-15010d62aab7.png)

## Saving Credentials on Bitwarden

Now when we go to the website where we registered our details manually, we can select the browser extension and it should filter to the url it matched, and when you hover over it you should see that it can auto-fill the login details:

![image](https://user-images.githubusercontent.com/567298/122879467-36bec280-d339-11eb-9039-7c9a43437c87.png)

After selecting it we can see it auto filled the credentials:

![image](https://user-images.githubusercontent.com/567298/122879657-708fc900-d339-11eb-92b6-ef99a6aca088.png)

When you log into a website and the credentials was not found on bitwarden it should prompt you to save the credentials automatically:

![image](https://user-images.githubusercontent.com/567298/122880063-dda35e80-d339-11eb-9376-9b75b7023345.png)

When we head back to our vault, we should see our item was saved:

![image](https://user-images.githubusercontent.com/567298/122880572-6de1a380-d33a-11eb-9b6b-df7d83b3bce4.png)

Bitwarden's vault also provides a tool to generate passwords which is handy:

![image](https://user-images.githubusercontent.com/567298/122880745-9f5a6f00-d33a-11eb-8aed-f3701109a382.png)

## Thank You

Thanks for reading, if you like my content, check out my **[website](https://ruan.dev)** or follow me at **[@ruanbekker](https://twitter.com/ruanbekker)** on Twitter.
