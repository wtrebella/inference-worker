#!/usr/bin/env bash

docker buildx build --platform linux/amd64 -t whitakr/chatbot-worker:latest .
docker push whitakr/chatbot-worker:latest
