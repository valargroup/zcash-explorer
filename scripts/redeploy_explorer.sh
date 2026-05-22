#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  scripts/redeploy_explorer.sh [--service explorer-testnet|explorer-mainnet] [--host user@host] [--remote-dir DIR]

Redeploy only the zcash-explorer Docker Compose service.

Modes:
  local   Without --host, rebuilds and restarts the selected service in this checkout.
  remote  With --host, uploads this checkout to --remote-dir and rebuilds/restarts there.

Defaults:
  --service     explorer-testnet
  --remote-dir  /root/zcash-explorer

Environment equivalents:
  EXPLORER_SERVICE, EXPLORER_SSH_HOST, EXPLORER_REMOTE_DIR
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
service="${EXPLORER_SERVICE:-explorer-testnet}"
host="${EXPLORER_SSH_HOST:-}"
remote_dir="${EXPLORER_REMOTE_DIR:-/root/zcash-explorer}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --service)
            service="${2:?--service requires a value}"
            shift 2
            ;;
        --host)
            host="${2:?--host requires a value}"
            shift 2
            ;;
        --remote-dir)
            remote_dir="${2:?--remote-dir requires a value}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$service" in
    explorer-mainnet|explorer-testnet) ;;
    *)
        echo "Unsupported service: $service" >&2
        echo "Expected explorer-mainnet or explorer-testnet." >&2
        exit 2
        ;;
esac

compose() {
    if docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    else
        docker-compose "$@"
    fi
}

if [[ -z "$host" ]]; then
    cd "$repo_root"
    compose up -d --build --remove-orphans "$service"
    exit 0
fi

remote_tmp="${remote_dir}.deploy.$(date +%Y%m%d%H%M%S)"

tar \
    --exclude='.git' \
    --exclude='.env' \
    --exclude='_build' \
    --exclude='deps' \
    --exclude='assets/node_modules' \
    --exclude='node_modules' \
    -C "$repo_root" \
    -czf - . |
    ssh "$host" "set -euo pipefail
        mkdir -p '$remote_tmp'
        tar -xzf - -C '$remote_tmp'
        if [ -f '$remote_dir/.env' ]; then
            cp '$remote_dir/.env' '$remote_tmp/.env'
        fi
        if [ ! -f '$remote_tmp/.env' ]; then
            echo 'Missing $remote_tmp/.env. Create it from .env.example or deploy into an existing remote dir with .env.' >&2
            rm -rf '$remote_tmp'
            exit 1
        fi
        if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
            compose_cmd='docker compose'
        elif command -v docker-compose >/dev/null 2>&1; then
            compose_cmd='docker-compose'
        else
            echo 'Docker Compose is not installed on the remote host.' >&2
            rm -rf '$remote_tmp'
            exit 1
        fi
        previous=''
        if [ -d '$remote_dir' ]; then
            previous='$remote_dir.previous'
            rm -rf \"\$previous\"
            mv '$remote_dir' \"\$previous\"
        fi
        mv '$remote_tmp' '$remote_dir'
        cd '$remote_dir'
        \$compose_cmd up -d --build --remove-orphans '$service'
        if [ -n \"\$previous\" ]; then
            rm -rf \"\$previous\"
        fi
    "
