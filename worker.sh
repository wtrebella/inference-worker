#!/usr/bin/env bash
set -euo pipefail

IMAGE="whitakr/chatbot-worker:latest"

export DOCKER_CLIENT_TIMEOUT="${DOCKER_CLIENT_TIMEOUT:-1800}"
export COMPOSE_HTTP_TIMEOUT="${COMPOSE_HTTP_TIMEOUT:-1800}"

BUILD=0
PUSH=0

Usage()
{
  echo ""
  echo "Usage: $0 [-bp]"
  echo ""
  echo "-h: help"
  echo "-b: build image"
  echo "-p: push image"
  echo ""
}

while getopts ":bph" opt; do
  case "$opt" in
    b) BUILD=1 ;;
    p) PUSH=1 ;;
    h) Usage; exit 1 ;;
    \?) echo "Missing options for -$OPTARG"; Usage; exit 1 ;;
    :) echo "Missing value for -$OPTARG"; Usage; exit 1 ;;
  esac
done

shift $((OPTIND - 1))

if [[ $# -ne 0 ]]; then
  echo "Unexpected positional args: $*"
  Usage
  exit 1
fi

if ((BUILD == 0 && PUSH == 0)); then
  echo "Neither -b nor -p were included, will build and push"
  BUILD=1
  PUSH=1
fi

if ((BUILD == 1)); then
  echo "Building $IMAGE"

  docker buildx build --platform linux/amd64 --load -t "$IMAGE" .
fi

if ((PUSH == 1)); then
  echo "Pushing $IMAGE"

  if ! docker push "$IMAGE"; then
    echo ""
    echo "Failed push of $IMAGE"
    exit 1
  fi
fi
