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
  if ! command -v cloudflared >/dev/null 2>&1; then
    echo "cloudflared is not installed in the container image" >&2
    exit 1
  fi

  if [ "${TUNNEL_MODE}" = "token" ]; then
    if [ -z "${TUNNEL_TOKEN:-}" ]; then
      echo "CF_TUNNEL_MODE=token requires TUNNEL_TOKEN" >&2
      exit 1
    fi
    echo "Starting Cloudflare named tunnel..."
    cloudflared tunnel --no-autoupdate run --token "${TUNNEL_TOKEN}" &
  else
    echo "Starting Cloudflare Quick Tunnel..."
    cloudflared tunnel --no-autoupdate --url "http://127.0.0.1:8317" &
  fi
fi

exec /CLIProxyAPI/CLIProxyAPI
