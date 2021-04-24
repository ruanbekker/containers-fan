---
title: "Run AWS Lambda Functions on Docker"
date: 2021-04-23T23:43:54+02:00
draft: false
description: "Tutorial on how to run local aws lambda functions with the help of docker."
tags: ["docker", "containers", "lambda"]
categories: ["containers"]
---

In this tutorial we will demonstrate how to run local aws lambda functions with the help of docker and running it locally on a container.

## Dockerfile

In our `Dockerfile`:

```dockerfile
FROM public.ecr.aws/lambda/python:3.8
COPY lambda_function.py ${LAMBDA_TASK_ROOT}/
COPY requirements.txt /opt/requirements.txt
RUN pip install -r /opt/requirements.txt -t ${LAMBDA_TASK_ROOT}/
CMD [ "lambda_function.handler" ]
```

## Lambda Function

Our application code, residing in our `lambda_function.py`:

```python
import json
import requests

def handler(event, context):
    body = {
        "message": "this is a message",
        "input": event
    }
    response = {
        "statusCode": 200,
        "body": json.dumps(body)
    }
    print(response)
    return response
```

## Build and Test

Build our docker container:

```
$ docker build -f Dockerfile -t my-local-lambda:v1 .
```

Run the container from our image and expose port 8080:

```
$ docker run -it -p 8080:8080 my-local-lambda:v1
```

Invoke the function from another terminal:

```
$ curl -XPOST "http://localhost:8080/2015-03-31/functions/function/invocations" -d '{"payload":"hello world!"}'
{"statusCode": 200, "body": "{\"message\": \"this is a message\", \"input\": {\"payload\": \"hello world!\"}}"}
```

We can also view our logs from docker stdout:

```
START RequestId: cc056596-e18a-4bb5-bb72-9f133a9dd397 Version: $LATEST
{'statusCode': 200, 'body': '{"message": "this is a message", "input": {"payload": "hello world!"}}'}
END RequestId: cc056596-e18a-4bb5-bb72-9f133a9dd397
REPORT RequestId: cc056596-e18a-4bb5-bb72-9f133a9dd397	Init Duration: 0.31 ms	Duration: 155.98 ms	Billed Duration: 200 ms	Memory Size: 3008 MB	Max Memory Used: 3008 MB
```

## Resources

- https://docs.aws.amazon.com/lambda/latest/dg/images-create.html
- https://aripalo.com/blog/2020/aws-lambda-container-image-support/
- https://www.philschmid.de/aws-lambda-with-custom-docker-image
