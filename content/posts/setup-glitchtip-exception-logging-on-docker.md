---
title: "Setup Glitchtip Exception Monitoring on Docker with Traefik"
date: 2021-10-04T07:00:00+02:00
draft: false
description: "Tutorial on setting up glitchtip exception monitoring on docker and docker-compose, the open-source alternative to Sentry."
tags: ["docker", "glitchtip", "monitoring"]
categories: ["containers"]
---

**[Glitchtip](https://glitchtip.com/)** is a open-source exception monitoring system, it's similar to **[Sentry](https://sentry.io/welcome/)**, which collects errors reported from your applications and helps you discover **errors** in real time and also helps you to understand the health of your applications. 

## What are we doing today?

In this tutorial we will setup **Glitchtip** on **Docker** using **Traefik** as our Load Balancer and SSL terminations for LetsEncrypt certificates, then we will create a Python Flask application and initiate a error so that we can see how these errors are collected by **Glitchtip** and we will also add an Webhook Server to demonstrate logging errors to a Webhook Endpoint for further development on errors.

So that we can see our exceptions in our applications like this:

![](https://user-images.githubusercontent.com/567298/135032641-b55fad6b-c010-4ba7-b783-fdc49fd69d69.png)

## Assumptions

I will assume that you have [docker](https://docs.docker.com/get-docker/) and [docker-compose](https://docs.docker.com/compose/install/) installed. If you need more info on [Traefik](https://traefik.io/) you can have a look at their website, but I have also written a post on setting up [Traefik v2](https://containers.fan/posts/setup-traefik-v2-docker-compose/) in detail, but we will touch on that in this post.

## Code Source

I will publish the code for this tutorial under my [Github Repository](https://github.com/ruanbekker/docker-glitchtip-traefik):
- https://github.com/ruanbekker/docker-glitchtip-traefik

## Environment Details

I have 3 DNS Entries:

- Glitchtip: `gc.civo.rbkr.xyz`
- Flask App: `flask-app.civo.rbkr.xyz`
- Webhook: `flask-webhook.civo.rbkr.xyz`

Which all points to the host running Glitchtip.

## Directory Structure

First create the directory structure for our glitchtip demo and change to the directory:

```
mkdir glitchtip-tutorial
cd glitchtip-tutorial
```

Create the traefik directory for `acme.json` where certificate data will be stored, create the file and change permissions on the file:

```
mkdir traefik
touch traefik/acme.json
chmod 600 traefik/acme.json
```

## Traefik

Open the `docker-compose.yml` and add the first bit which will Traefik, ensure that you replace `me@example.com` with your email under `certificatesResolvers.letsencrypt.acme.email`: 

```yaml
version: '3.8'

x-logging:
  &default-logging
  driver: "json-file"
  options:
    max-size: "1m"

services:
  glitchtip-traefik:
    image: traefik:2.4
    container_name: glitchtip-traefik
    restart: unless-stopped
    volumes:
      - ./traefik/acme.json:/acme.json
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - glitchtip
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
      - '--certificatesResolvers.letsencrypt.acme.email=me@example.com'
      - '--certificatesResolvers.letsencrypt.acme.storage=acme.json'
      - '--certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=http'
      - '--log=true'
      - '--log.level=INFO'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

networks:
  glitchtip:
    name: glitchtip
```

You can now start Traefik so long:

```bash
docker-compose up -d
```

## Glitchtip

Now we will add the Glitchtip components, you can refer to their [documentation](https://glitchtip.com/documentation/install) if you want to read more into these configuration options. Add the following services below `glitchtip-traefk`:

```yaml
  glitchtip-postgres:
    image: postgres:13
    container_name: glitchtip-postgres
    restart: unless-stopped
    environment:
      POSTGRES_HOST_AUTH_METHOD: "trust"
      POSTGRES_DB: postgres
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    networks:
      - glitchtip
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 5s
      retries: 5
    logging: *default-logging

  glitchtip-redis:
    image: redis
    container_name: glitchtip-redis
    restart: unless-stopped
    networks:
      - glitchtip
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 30s
      retries: 50
    logging: *default-logging

  glitchtip-web:
    image: glitchtip/glitchtip
    container_name: glitchtip-web
    restart: unless-stopped
    depends_on:
      glitchtip-traefik:
        condition: service_started
      glitchtip-postgres:
        condition: service_healthy
      glitchtip-redis:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://postgres:postgres@glitchtip-postgres:5432/postgres
      REDIS_URL: redis://glitchtip-redis:6379/0
      SECRET_KEY: jsdf93892309fhufhr
      PORT: 8000
      EMAIL_URL: "${EMAIL_URL}"
      DEFAULT_FROM_EMAIL: ${EMAIL_FROM_ADDRESS}
      GLITCHTIP_DOMAIN: "https://gt.civo.rbkr.xyz"
      ENABLE_OPEN_USER_REGISTRATION: "True"
      GLITCHTIP_MAX_EVENT_LIFE_DAYS: 90
    networks:
      - glitchtip
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.glitchtip.rule=Host(`gt.civo.rbkr.xyz`)'
      - 'traefik.http.routers.glitchtip.entrypoints=https'
      - 'traefik.http.routers.glitchtip.tls=true'
      - 'traefik.http.routers.glitchtip.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.glitchtip.service=glitchtip-service'
      - 'traefik.http.services.glitchtip-service.loadbalancer.server.port=8000'
    logging: *default-logging

  glitchtip-worker:
    image: glitchtip/glitchtip
    container_name: glitchtip-worker
    restart: unless-stopped
    command: celery -A glitchtip worker -B -l INFO
    depends_on:
      glitchtip-postgres:
        condition: service_healthy
      glitchtip-redis:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://postgres:postgres@glitchtip-postgres:5432/postgres
      REDIS_URL: redis://glitchtip-redis:6379/0
      SECRET_KEY: jsdf93892309fhufhr
      PORT: 8000
      EMAIL_URL: "${EMAIL_URL}"
      DEFAULT_FROM_EMAIL: ${EMAIL_FROM_ADDRESS}
      GLITCHTIP_DOMAIN: "https://gt.civo.rbkr.xyz"
    networks:
      - glitchtip
    logging: *default-logging

  glitchtip-migrate:
    image: glitchtip/glitchtip
    container_name: glitchtip-migrate
    depends_on:
      glitchtip-postgres:
        condition: service_healthy
      glitchtip-redis:
        condition: service_healthy
    command: "./manage.py migrate"
    environment:
      DATABASE_URL: postgres://postgres:postgres@glitchtip-postgres:5432/postgres
      REDIS_URL: redis://glitchtip-redis:6379/0
      SECRET_KEY: jsdf93892309fhufhr
      PORT: 8000
      EMAIL_URL: "${EMAIL_URL}"
      DEFAULT_FROM_EMAIL: ${EMAIL_FROM_ADDRESS}
      GLITCHTIP_DOMAIN: "https://gt.civo.rbkr.xyz"
    networks:
      - glitchtip
    logging: *default-logging
```

Ensure that you change the following:

- `EMAIL_URL` eg. `smtp://apikey:your-password@smtp.sendgrid.net:587` ([sendgrid](https://www.twilio.com/sendgrid/email-api) offers free mail delivery)
- `DEFAULT_FROM_EMAIL` eg. `no-reply@yourdomain.com`
- Your FQDN for glitchtip in `'traefik.http.routers.glitchtip.rule=Host()'`

Once your configuration is updated, start glitchtip:

```
docker-compose pull
docker-compose up -d
```

Once all the services are started you should be able to access the UI and will look more or less like this:

![image](https://user-images.githubusercontent.com/567298/134298772-364e3201-4ac2-49bd-b742-039ed6c65ac7.png)

Since `ENABLE_OPEN_USER_REGISTRATION` is set to `True`, we can register our user:

![image](https://user-images.githubusercontent.com/567298/134299373-402545d1-b38d-46d0-9136-f51862845e95.png)

Once you register you will be logged in and on the organization page to create a organization:

![image](https://user-images.githubusercontent.com/567298/134299523-146de249-227d-4d91-890e-2a30559abe40.png)

For this tutorial, I will be using the name `my-org`:

![image](https://user-images.githubusercontent.com/567298/134299629-b2a6b7d4-b48f-430f-96e5-482aa614109b.png)

I will go ahead and create a application in my organisation called `flask-service-dev` and I will be selecting Python Flask for this tutorial, and I want to associate this project to a team called `engineering`, at the bottom select team and create your team:

![image](https://user-images.githubusercontent.com/567298/134300030-33becf05-bcc3-4ef9-8c5f-8ed3a632b783.png)

Once the team has been created and selected, select the framework and name your service:

![image](https://user-images.githubusercontent.com/567298/134300187-872a605b-8d9d-4ef0-a090-16fdec3c05d2.png)

Once you created your project you will get a getting started guide on how to configure your application:

![image](https://user-images.githubusercontent.com/567298/134300361-543de10f-d775-47f8-a9d6-7a2b60ea8329.png)

On the right hand side you will get the configuration values, which we will use as environment variables on our application that we want to emit errors to glitchtip:
- `https://6ee24c1a446347b99e9574edfe990393@gt.civo.rbkr.xyz/1`
- `https://gt.civo.rbkr.xyz/api/1/security/?glitchtip_key=6ee24c1a446347b99e9574edfe990393`

Now that we have signed up we can disable `ENABLE_OPEN_USER_REGISTRATION` by setting it to `False` in the `docker-compose.yml`, then run `docker-compose up -d`.

Optional: Glitchtip is written in Django, so you can also use the following method to manage users and access the admin panel on `/admin`:

```
$ docker-compose run glitchtip-migrate ./manage.py createsuperuser
Creating glitchdip_glitchtip-migrate_run ... done
Email: me@example.com
Password:
Password (again):
Superuser created successfully.
```

## Python Flask App

Now we will create the application that we want to monitor for errors on glitchtip. From the `glitchtip-tutorial` directory, create the application code and dockerfile for our python flask app:

```
mkdir flask-app
touch flask-app/requirements.txt
touch flask-app/app.py
touch flask-app/Dockerfile
```

First add the requirements in `flask-app/requirements.txt`:

```
flask==1.1.2
sentry-sdk[flask]
gunicorn==20.0.4
```

Next our dockerfile in `flask-app/Dockerfile`:

```dockerfile
FROM python:3.8-slim
ADD requirements.txt /src/requirements.txt
ADD run.sh /src/run.sh
RUN chmod +x /src/run.sh
RUN pip install --upgrade -r /src/requirements.txt
ADD app.py /src/app.py
CMD ["/src/run.sh"]
```

Our boot script that will start flask using gunicorn in `flask-app/run.sh`:

```bash
#!/bin/sh
gunicorn app:app \
	--workers 2 \
	--threads 2 \
	--bind 0.0.0.0:80 \
	--capture-output \
	--access-logfile '-' \
	--error-logfile '-'
```

Then our application code in `flask-app/app.py`:

```python
import os
import logging
from flask import Flask
import sentry_sdk
from sentry_sdk.integrations.flask import FlaskIntegration

GLITCHTIP_DSN = os.environ['DSN']

sentry_sdk.init(
    dsn=GLITCHTIP_DSN,
    integrations=[FlaskIntegration()]
)

app = Flask(__name__)
app.config['DEBUG'] = False

@app.before_first_request
def setup_logging():
    app.logger.addHandler(logging.StreamHandler())
    app.logger.setLevel(logging.INFO)
    app.logger.info('logs enabled')

@app.route('/')
def root():
    return 'hello, world'

@app.route('/log-error')
def log_error():
    app.logger.error('logging error with glitchtip')
    return 'logged error'

@app.route('/trigger-error')
def trigger_error():
    division_by_zero = 1 / 0

if __name__ == '__main__':
    app.logger.info('starting server')
    app.run()
```

Then we add this section to our `docker-compose.yml`:

```
  glitchtip-flask-app:
    build:
      context: flask-app
      dockerfile: Dockerfile
    container_name: glitchtip-flask-app
    restart: unless-stopped
    depends_on:
      glitchtip-traefik:
        condition: service_started
    environment:
      DSN: "https://6ee24c1a446347b99e9574edfe990393@gt.civo.rbkr.xyz/1"
    networks:
      - glitchtip
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.app.rule=Host(`flask-app.civo.rbkr.xyz`)'
      - 'traefik.http.routers.app.entrypoints=https'
      - 'traefik.http.routers.app.tls=true'
      - 'traefik.http.routers.app.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.app.service=app-service'
      - 'traefik.http.services.app-service.loadbalancer.server.port=80'
    logging: *default-logging
```

So now our full `docker-compose.yml` should look like this more or less:

```
---
version: '3.8'

x-logging:
  &default-logging
  driver: "json-file"
  options:
    max-size: "1m"

services:
  glitchtip-traefik:
    image: traefik:2.4
    container_name: glitchtip-traefik
    restart: unless-stopped
    volumes:
      - ./traefik/acme.json:/acme.json
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - glitchtip
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
      - '--certificatesResolvers.letsencrypt.acme.email=me@example.com'
      - '--certificatesResolvers.letsencrypt.acme.storage=acme.json'
      - '--certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=http'
      - '--log=true'
      - '--log.level=INFO'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  glitchtip-postgres:
    image: postgres:13
    container_name: glitchtip-postgres
    restart: unless-stopped
    environment:
      POSTGRES_HOST_AUTH_METHOD: "trust"
      POSTGRES_DB: postgres
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    networks:
      - glitchtip
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 5s
      retries: 5
    logging: *default-logging

  glitchtip-redis:
    image: redis
    container_name: glitchtip-redis
    restart: unless-stopped
    networks:
      - glitchtip
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 30s
      retries: 50
    logging: *default-logging

  glitchtip-web:
    image: glitchtip/glitchtip
    container_name: glitchtip-web
    restart: unless-stopped
    depends_on:
      glitchtip-traefik:
        condition: service_started
      glitchtip-postgres:
        condition: service_healthy
      glitchtip-redis:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://postgres:postgres@glitchtip-postgres:5432/postgres
      REDIS_URL: redis://glitchtip-redis:6379/0
      SECRET_KEY: jsdf93892309fhufhr
      PORT: 8000
      EMAIL_URL: "${EMAIL_URL}"
      DEFAULT_FROM_EMAIL: ${EMAIL_FROM_ADDRESS}
      GLITCHTIP_DOMAIN: "https://gt.civo.rbkr.xyz"
      ENABLE_OPEN_USER_REGISTRATION: "False"
      GLITCHTIP_MAX_EVENT_LIFE_DAYS: 90
    networks:
      - glitchtip
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.glitchtip.rule=Host(`gt.civo.rbkr.xyz`)'
      - 'traefik.http.routers.glitchtip.entrypoints=https'
      - 'traefik.http.routers.glitchtip.tls=true'
      - 'traefik.http.routers.glitchtip.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.glitchtip.service=glitchtip-service'
      - 'traefik.http.services.glitchtip-service.loadbalancer.server.port=8000'
    logging: *default-logging

  glitchtip-worker:
    image: glitchtip/glitchtip
    container_name: glitchtip-worker
    restart: unless-stopped
    command: celery -A glitchtip worker -B -l INFO
    depends_on:
      glitchtip-postgres:
        condition: service_healthy
      glitchtip-redis:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://postgres:postgres@glitchtip-postgres:5432/postgres
      REDIS_URL: redis://glitchtip-redis:6379/0
      SECRET_KEY: jsdf93892309fhufhr
      PORT: 8000
      EMAIL_URL: "${EMAIL_URL}"
      DEFAULT_FROM_EMAIL: ${EMAIL_FROM_ADDRESS}
    networks:
      - glitchtip
    logging: *default-logging

  glitchtip-migrate:
    image: glitchtip/glitchtip
    container_name: glitchtip-migrate
    depends_on:
      glitchtip-postgres:
        condition: service_healthy
      glitchtip-redis:
        condition: service_healthy
    command: "./manage.py migrate"
    environment:
      DATABASE_URL: postgres://postgres:postgres@glitchtip-postgres:5432/postgres
      REDIS_URL: redis://glitchtip-redis:6379/0
      SECRET_KEY: jsdf93892309fhufhr
      PORT: 8000
      EMAIL_URL: "${EMAIL_URL}"
      DEFAULT_FROM_EMAIL: ${EMAIL_FROM_ADDRESS}
      GLITCHTIP_DOMAIN: "https://gt.civo.rbkr.xyz"
    networks:
      - glitchtip
    logging: *default-logging

  glitchtip-flask-app:
    build:
      context: flask-app
      dockerfile: Dockerfile
    container_name: glitchtip-flask-app
    restart: unless-stopped
    depends_on:
      glitchtip-traefik:
        condition: service_started
    environment:
      DSN: "https://6ee24c1a446347b99e9574edfe990393@gt.civo.rbkr.xyz/1"
    networks:
      - glitchtip
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.app.rule=Host(`flask-app.civo.rbkr.xyz`)'
      - 'traefik.http.routers.app.entrypoints=https'
      - 'traefik.http.routers.app.tls=true'
      - 'traefik.http.routers.app.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.app.service=app-service'
      - 'traefik.http.services.app-service.loadbalancer.server.port=80'
    logging: *default-logging

networks:
  glitchtip:
    name: glitchtip
```

Build the `flask-app` container and start the service:

```bash
docker-compose up --build -d
```

Making a test request:

```
$ curl -IL http://flask-app.civo.rbkr.xyz
HTTP/1.1 308 Permanent Redirect
Location: https://flask-app.civo.rbkr.xyz/
Date: Tue, 28 Sep 2021 06:00:27 GMT
Content-Length: 18
Content-Type: text/plain; charset=utf-8

HTTP/2 200
content-type: text/html; charset=utf-8
date: Tue, 28 Sep 2021 06:00:27 GMT
server: gunicorn/20.0.4
content-length: 12
```

## Logging Exceptions to Glitchtip

Now let's access the endpoints that will cause an exception, let's first make a request to `/trigger-error`, then head over to "Issues", or if you have multiple projects, select your organization, then select your project's issues:

![image](https://user-images.githubusercontent.com/567298/135031981-95eef0cd-361c-4bed-9aaa-f050e38591b7.png)

From the issues view, we can see we had one issue:

![image](https://user-images.githubusercontent.com/567298/135032472-67b7ddd7-2fde-4ef7-8172-57b2290509aa.png)

When we select the issue, we can see more information about this exception, such as the useragent info, the request path, where in our application the exception was raised etc:

![image](https://user-images.githubusercontent.com/567298/135032641-b55fad6b-c010-4ba7-b783-fdc49fd69d69.png)

As you can see, Glitchtip also provide information deeper in the stack where the exception was raised from:

![image](https://user-images.githubusercontent.com/567298/135032778-fc88d802-fbf1-4def-b7b0-da69a5ade6a3.png)

There's a lot of information, but what I also found nice, was that it logs span_id and trace_id, the sdk version etc:

![image](https://user-images.githubusercontent.com/567298/135033134-6334a144-5a16-400e-bd9d-f5becd774abb.png)

If we have a look at the `/log-error`, which will just log an error event, from the issues view, we can see we had one issue:

![image](https://user-images.githubusercontent.com/567298/135032049-42dc6ff8-9ea3-4fff-8ba5-f9153dac89b2.png)

When we select the issue, we can see more information about this exception, such as the useragent info, the request path, etc:

![image](https://user-images.githubusercontent.com/567298/135032216-6f299860-b5ca-4f4b-9726-726d6128d9fb.png)

## Alerting

We can setup alerting for every time we receive an exception, to do so, head over to "Settings", "Projects" and you will find "Project Alerts":

![image](https://user-images.githubusercontent.com/567298/135033497-f0a4822b-99c5-42a2-9bea-576ae113db61.png)

When we select "Create New Alert", you will get the alert configuration and by default the alert will be configured to the email address of the team members of the project. 

![image](https://user-images.githubusercontent.com/567298/135033683-b3841415-577f-4e13-865f-a75bc22ab5ef.png)

If we "Add Alert Recipient", you will see that we have the option to add a "Webhook URL", so let's go back to our `docker-compose.yml` and setup a Python Flask Webhook:

```
  glitchtip-flask-webhook:
    build:
      context: flask-webhook
      dockerfile: Dockerfile
    container_name: glitchtip-flask-webhook
    restart: unless-stopped
    depends_on:
      glitchtip-traefik:
        condition: service_started
    networks:
      - glitchtip
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.webhook.rule=Host(`flask-webhook.civo.rbkr.xyz`)'
      - 'traefik.http.routers.webhook.entrypoints=https'
      - 'traefik.http.routers.webhook.tls=true'
      - 'traefik.http.routers.webhook.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.webhook.service=webhook-service'
      - 'traefik.http.services.webhook-service.loadbalancer.server.port=80'
    logging: *default-logging
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/health"]
      interval: 5s
      timeout: 3s
      retries: 60
```

Then we create our flask-webhook directory:

```
mkdir flask-webhook
```

Create the required files, first our application `flask-webhook/app.py`:

```python
import logging
from flask import Flask, request, jsonify

app = Flask(__name__)
app.config['DEBUG'] = False

@app.before_first_request
def setup_logging():
    app.logger.addHandler(logging.StreamHandler())
    app.logger.setLevel(logging.INFO)

@app.route('/', methods=['POST'])
def webhook():
    payload = request.get_json(force=True)
    app.logger.info(payload)
    return jsonify(payload)

@app.route('/health', methods=['GET'])
def health():
    payload = {'status': 'up'}
    return jsonify(payload)

if __name__ == '__main__':
    app.logger.info('starting server')
    app.run()
```

Then our `flask-webhook/Dockerfile`:

```dockerfile
FROM python:3.8-slim
RUN apt update && apt install curl -y
WORKDIR /src
ADD requirements.txt /src/requirements.txt
ADD run.sh /src/run.sh
RUN chmod +x /src/run.sh
RUN pip install --upgrade -r /src/requirements.txt
ADD app.py /src/app.py

CMD ["/src/run.sh"]
```

Then our `flask-webhook/requirements.txt`:

```
flask==1.1.2
gunicorn==20.0.4
```

Then when everything is in place, build and start the container:

```
docker-compose up --build -d
```

Once the application has started, from Settings, Projects, Project Alerts, when we add a new alert recipient, we select the webhook as a recipient type and add our webhook url:

![image](https://user-images.githubusercontent.com/567298/135062331-437176eb-8863-4eec-b1c4-63b5c21056e9.png)

Now we should see:

![image](https://user-images.githubusercontent.com/567298/135062386-f8240051-f950-48be-be92-040573e1c513.png)

Select submit and then invoke the `/trigger-error` url:

```
$ curl -I https://flask-app.civo.rbkr.xyz/trigger-error
HTTP/2 500
content-type: text/html; charset=utf-8
date: Tue, 28 Sep 2021 09:36:29 GMT
server: gunicorn/20.0.4
content-length: 290
```

Now when we look at the logs of our webhook container:

```
$ docker-compose logs -f glitchtip-flask-webhook
...
glitchtip-flask-webhook    | {'alias': 'GlitchTip', 'text': 'GlitchTip Alert', 'attachments': [{'title': 'ZeroDivisionError: division by zero', 'title_link': 'https://gt.civo.rbkr.xyz/my-org/issues/2', 'text': 'trigger_error', 'image_url': None, 'color': '#e52b50'}], 'sections': [{'activityTitle': 'ZeroDivisionError: division by zero', 'activitySubtitle': '[View Issue FLASK-SERVICE-DEV-1](https://gt.civo.rbkr.xyz/my-org/issues/2)'}]}
```
If we prettify it, you can see we can consume this information and do our own integrations:

```
>>> print(json.dumps(e, indent=2))
{
  "alias": "GlitchTip",
  "text": "GlitchTip Alert",
  "attachments": [
    {
      "title": "ZeroDivisionError: division by zero",
      "title_link": "https://gt.civo.rbkr.xyz/my-org/issues/2",
      "text": "trigger_error",
      "image_url": null,
      "color": "#e52b50"
    }
  ],
  "sections": [
    {
      "activityTitle": "ZeroDivisionError: division by zero",
      "activitySubtitle": "[View Issue FLASK-SERVICE-DEV-1](https://gt.civo.rbkr.xyz/my-org/issues/2)"
    }
  ]
}
```

And our email notification will look like this:

<img width="1154" alt="image" src="https://user-images.githubusercontent.com/567298/135065119-be98faff-1c70-47f3-812a-893c348ffd50.png">

## The Complete Compose

This will be published to my [github repository](https://github.com/ruanbekker/docker-glitchtip-traefik), but the complete `docker-compose.yml`:

```yaml
---
version: '3.8'

x-logging:
  &default-logging
  driver: "json-file"
  options:
    max-size: "1m"

services:
  glitchtip-traefik:
    image: traefik:2.4
    container_name: glitchtip-traefik
    restart: unless-stopped
    volumes:
      - ./traefik/acme.json:/acme.json
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - glitchtip
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
      - '--certificatesResolvers.letsencrypt.acme.email=email@example.com'
      - '--certificatesResolvers.letsencrypt.acme.storage=acme.json'
      - '--certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=http'
      - '--log=true'
      - '--log.level=INFO'
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

  glitchtip-postgres:
    image: postgres:13
    container_name: glitchtip-postgres
    restart: unless-stopped
    environment:
      POSTGRES_HOST_AUTH_METHOD: "trust"
      POSTGRES_DB: postgres
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    networks:
      - glitchtip
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 5s
      retries: 5
    logging: *default-logging

  glitchtip-redis:
    image: redis
    container_name: glitchtip-redis
    restart: unless-stopped
    networks:
      - glitchtip
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 30s
      retries: 50
    logging: *default-logging

  glitchtip-web:
    image: glitchtip/glitchtip
    container_name: glitchtip-web
    restart: unless-stopped
    depends_on:
      glitchtip-traefik:
        condition: service_started
      glitchtip-postgres:
        condition: service_healthy
      glitchtip-redis:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://postgres:postgres@glitchtip-postgres:5432/postgres
      REDIS_URL: redis://glitchtip-redis:6379/0
      SECRET_KEY: jsdf93892309fhufhr
      PORT: 8000
      EMAIL_URL: "${EMAIL_URL}"
      DEFAULT_FROM_EMAIL: ${EMAIL_FROM_ADDRESS}
      GLITCHTIP_DOMAIN: "https://gt.civo.rbkr.xyz"
      ENABLE_OPEN_USER_REGISTRATION: "False"
      GLITCHTIP_MAX_EVENT_LIFE_DAYS: 90
    networks:
      - glitchtip
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.glitchtip.rule=Host(`gt.civo.rbkr.xyz`)'
      - 'traefik.http.routers.glitchtip.entrypoints=https'
      - 'traefik.http.routers.glitchtip.tls=true'
      - 'traefik.http.routers.glitchtip.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.glitchtip.service=glitchtip-service'
      - 'traefik.http.services.glitchtip-service.loadbalancer.server.port=8000'
    logging: *default-logging

  glitchtip-worker:
    image: glitchtip/glitchtip
    container_name: glitchtip-worker
    restart: unless-stopped
    command: celery -A glitchtip worker -B -l INFO
    depends_on:
      glitchtip-postgres:
        condition: service_healthy
      glitchtip-redis:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://postgres:postgres@glitchtip-postgres:5432/postgres
      REDIS_URL: redis://glitchtip-redis:6379/0
      SECRET_KEY: jsdf93892309fhufhr
      PORT: 8000
      EMAIL_URL: "${EMAIL_URL}"
      DEFAULT_FROM_EMAIL: ${EMAIL_FROM_ADDRESS}
      GLITCHTIP_DOMAIN: "https://gt.civo.rbkr.xyz"
    networks:
      - glitchtip
    logging: *default-logging

  glitchtip-migrate:
    image: glitchtip/glitchtip
    container_name: glitchtip-migrate
    depends_on:
      glitchtip-postgres:
        condition: service_healthy
      glitchtip-redis:
        condition: service_healthy
    command: "./manage.py migrate"
    environment:
      DATABASE_URL: postgres://postgres:postgres@glitchtip-postgres:5432/postgres
      REDIS_URL: redis://glitchtip-redis:6379/0
      SECRET_KEY: jsdf93892309fhufhr
      PORT: 8000
      EMAIL_URL: "${EMAIL_URL}"
      DEFAULT_FROM_EMAIL: ${EMAIL_FROM_ADDRESS}
      GLITCHTIP_DOMAIN: "https://gt.civo.rbkr.xyz"
    networks:
      - glitchtip
    logging: *default-logging

  glitchtip-flask-app:
    build:
      context: flask-app
      dockerfile: Dockerfile
    container_name: glitchtip-flask-app
    restart: unless-stopped
    depends_on:
      glitchtip-traefik:
        condition: service_started
    environment:
      DSN: "https://6ee24c1a446347b99e9574edfe990393@gt.civo.rbkr.xyz/1"
    networks:
      - glitchtip
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.app.rule=Host(`flask-app.civo.rbkr.xyz`)'
      - 'traefik.http.routers.app.entrypoints=https'
      - 'traefik.http.routers.app.tls=true'
      - 'traefik.http.routers.app.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.app.service=app-service'
      - 'traefik.http.services.app-service.loadbalancer.server.port=80'
    logging: *default-logging

  glitchtip-flask-webhook:
    build:
      context: flask-webhook
      dockerfile: Dockerfile
    container_name: glitchtip-flask-webhook
    restart: unless-stopped
    depends_on:
      glitchtip-traefik:
        condition: service_started
    networks:
      - glitchtip
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.webhook.rule=Host(`flask-webhook.civo.rbkr.xyz`)'
      - 'traefik.http.routers.webhook.entrypoints=https'
      - 'traefik.http.routers.webhook.tls=true'
      - 'traefik.http.routers.webhook.tls.certresolver=letsencrypt'
      - 'traefik.http.routers.webhook.service=webhook-service'
      - 'traefik.http.services.webhook-service.loadbalancer.server.port=80'
    logging: *default-logging
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/health"]
      interval: 5s
      timeout: 3s
      retries: 60

networks:
  glitchtip:
    name: glitchtip
```

I left the domain endpoints and glitchtip application keys in the code intentionally for demonstration purposes, but deleted the stack after the time of writing.

## Thank You

I hope this was helpful, I was really impressed with Glitchtip. If you liked this content, please make sure to share or come say hi on my website or twitter:

  * **Website**: [ruan.dev](https://ruan.dev)
  * **Twitter**: [@ruanbekker](https://twitter.com/ruanbekker)
