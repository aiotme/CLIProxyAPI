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

exec /CLIProxyAPI/CLIProxyAPI
