#!/usr/bin/env sh
set -eu

cat > /CLIProxyAPI/config.yaml <<EOF
host: "0.0.0.0"
port: 8317
auth-dir: "/tmp/.cli-proxy-api"
tls:
  enable: false
api-keys:
  - "${API_KEY}"
remote-management:
  allow-remote: true
  secret-key: "${MGMT_SECRET}"
nonstream-keepalive-interval: 15
EOF

TUNNEL_MODE="${CF_TUNNEL_MODE:-quick}"

case "${TUNNEL_MODE}" in
  off|quick|token)
    ;;
  *)
    echo "Invalid CF_TUNNEL_MODE: ${TUNNEL_MODE} (allowed: off|quick|token)" >&2
    exit 1
    ;;
esac

if [ "${TUNNEL_MODE}" != "off" ]; then
  CLOUDFLARED_BIN=""
  if command -v cloudflared >/dev/null 2>&1; then
    CLOUDFLARED_BIN="$(command -v cloudflared)"
  else
    ARCH="$(uname -m)"
    case "${ARCH}" in
      x86_64|amd64)
        CF_ARCH="amd64"
        ;;
      aarch64|arm64)
        CF_ARCH="arm64"
        ;;
      *)
        echo "Unsupported architecture for cloudflared: ${ARCH}" >&2
        exit 1
        ;;
    esac

    CLOUDFLARED_BIN="$(mktemp /tmp/cloudflared.XXXXXX)"
    wget -q -O "${CLOUDFLARED_BIN}" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}"
    chmod 700 "${CLOUDFLARED_BIN}"
  fi

  if [ "${TUNNEL_MODE}" = "token" ]; then
    if [ -z "${TUNNEL_TOKEN:-}" ]; then
      echo "CF_TUNNEL_MODE=token requires TUNNEL_TOKEN" >&2
      exit 1
    fi
    echo "Starting Cloudflare named tunnel..."
    "${CLOUDFLARED_BIN}" tunnel --no-autoupdate run --token "${TUNNEL_TOKEN}" &
  else
    RETRY_SECONDS="${CF_QUICK_TUNNEL_RETRY_SECONDS:-5}"
    case "${RETRY_SECONDS}" in
      ''|*[!0-9]*)
        RETRY_SECONDS="5"
        ;;
    esac

    (
      while true; do
        echo "Starting Cloudflare Quick Tunnel..."
        if "${CLOUDFLARED_BIN}" tunnel --no-autoupdate --url "http://127.0.0.1:8317"; then
          exit 0
        fi
        echo "Quick Tunnel exited, retrying in ${RETRY_SECONDS}s..." >&2
        sleep "${RETRY_SECONDS}"
      done
    ) &
  fi
fi

exec /CLIProxyAPI/CLIProxyAPI
