#!/usr/bin/env bash
set -euo pipefail

IMAGE="whitakr/chatbot-worker:latest"

export DOCKER_CLIENT_TIMEOUT="${DOCKER_CLIENT_TIMEOUT:-1800}"
export COMPOSE_HTTP_TIMEOUT="${COMPOSE_HTTP_TIMEOUT:-1800}"

if ! docker push "$IMAGE"; then
  echo ""
  echo "docker push failed; dumping Docker proxy info:"
  docker info 2>/dev/null | sed -n '/Proxy:/,/Registry Mirrors:/p' || true

  echo ""
  echo "env proxy vars:"
  env | egrep -i 'http_proxy|https_proxy|no_proxy' || true

  exit 1
fi
