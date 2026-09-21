#!/usr/bin/env bash
# Manage a floci container that is private to this checkout.
#
# The container name is <repo name>-floci-<hash of the checkout path>, so
# several worktrees of the same repository can run tests at the same time.
# Docker picks a free host port. Use `url` to find it.
#
# Usage: scripts/floci.sh start | stop | url | name

set -euo pipefail

FLOCI_IMAGE="${FLOCI_IMAGE:-floci/floci:2.1.0}"
FLOCI_PORT=4566

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Name of the main repository, even when called from a linked worktree.
repo_name() {
  local common_dir
  common_dir="$(git rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$common_dir" ]; then
    basename "$(dirname "$(cd "$common_dir" && pwd)")"
  else
    basename "$(repo_root)"
  fi
}

container_name() {
  local hash
  hash="$(printf '%s' "$(repo_root)" | shasum | cut -c1-8)"
  printf '%s-floci-%s\n' "$(repo_name)" "$hash"
}

container_url() {
  local name port
  name="$(container_name)"
  # `docker port` fails when the container does not exist. Do not let that
  # abort the script before the message below is printed.
  port="$(docker port "$name" "$FLOCI_PORT" 2>/dev/null | head -n1 | sed 's/.*://' || true)"
  if [ -z "$port" ]; then
    {
      echo "floci is not running for this checkout."
      echo "  container: $name"
      echo "  start it:  mise run floci:start"
    } >&2
    return 1
  fi
  printf 'http://localhost:%s\n' "$port"
}

start() {
  local name url
  name="$(container_name)"
  if [ -z "$(docker ps -q --filter "name=^${name}$")" ]; then
    docker rm -f "$name" > /dev/null 2>&1 || true
    docker run -d --name "$name" -p "127.0.0.1::${FLOCI_PORT}" "$FLOCI_IMAGE" > /dev/null
  fi
  url="$(container_url)"
  echo "Waiting for floci at $url"
  for _ in $(seq 1 60); do
    if curl -sf "$url/_floci/health" > /dev/null; then
      echo "floci is ready at $url"
      return 0
    fi
    sleep 2
  done
  echo "floci did not become ready in time" >&2
  docker logs "$name" >&2
  return 1
}

stop() {
  docker rm -f "$(container_name)" > /dev/null 2>&1 || true
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  url) container_url ;;
  name) container_name ;;
  *)
    echo "Usage: $0 start | stop | url | name" >&2
    exit 2
    ;;
esac
