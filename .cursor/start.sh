#!/usr/bin/env bash
# Cloud Agent start phase for the OpenTelemetry Demo.
# Starts the Docker daemon (if needed) and brings up the full demo stack.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Re-assert the legacy iptables backend in case the base image resets it.
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy >/dev/null 2>&1 || true
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy >/dev/null 2>&1 || true

if ! sudo docker info >/dev/null 2>&1; then
  sudo rm -f /var/run/docker.pid
  sudo bash -c 'nohup dockerd >/var/log/dockerd.log 2>&1 &'
  for _ in $(seq 1 30); do
    sudo docker info >/dev/null 2>&1 && break
    sleep 2
  done
fi

sudo docker info >/dev/null 2>&1 || { echo "Docker daemon failed to start" >&2; exit 1; }

# make start uses `docker compose`; run it through sudo so it works regardless of
# the invoking shell's docker group membership.
make start DOCKER_CMD="sudo docker" DOCKER_COMPOSE_CMD="sudo docker compose"
