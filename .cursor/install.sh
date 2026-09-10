#!/usr/bin/env bash
# Cloud Agent install phase for the OpenTelemetry Demo.
# Installs Docker Engine, configures it for the nested-container VM, and
# pre-pulls the demo images so the stack starts quickly. Safe to re-run.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

export DEBIAN_FRONTEND=noninteractive

if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -o Dpkg::Options::=--force-confold \
    ca-certificates curl gnupg fuse-overlayfs uidmap
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -o Dpkg::Options::=--force-confold \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# overlay2 cannot stack on the VM's overlay root filesystem, so use fuse-overlayfs.
sudo mkdir -p /etc/docker
printf '{\n  "storage-driver": "fuse-overlayfs"\n}\n' | sudo tee /etc/docker/daemon.json >/dev/null

# Docker's default nftables backend does not set up working bridge NAT in this
# nested VM; the legacy iptables backend does. See CONTRIBUTING.md troubleshooting.
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

sudo usermod -aG docker "$(id -un)" || true

# Pre-pull images into the baked snapshot. Start dockerd briefly if needed.
STARTED_DOCKERD=0
if ! sudo docker info >/dev/null 2>&1; then
  sudo rm -f /var/run/docker.pid
  sudo bash -c 'nohup dockerd >/var/log/dockerd.log 2>&1 &'
  STARTED_DOCKERD=1
  for _ in $(seq 1 30); do sudo docker info >/dev/null 2>&1 && break; sleep 2; done
fi

sudo docker compose \
  --env-file .env --env-file .env.override \
  -f compose.yaml -f compose.full.yaml -f compose.observability.yaml -f compose.extras.yaml \
  pull --ignore-pull-failures --quiet

if [ "$STARTED_DOCKERD" = "1" ]; then
  sudo pkill -x dockerd || true
fi

echo "install complete: Docker ready and demo images pulled."
