#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

die() {
    echo "$*" 1>&2
    exit 1
}

TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 30")

metadata() {
    curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/$1
}

cat <<EOF
ACCOUNT_ID=$(metadata "identity-credentials/ec2/info" | jq -r ".AccountId")
AVAILABILITY_ZONE=$(metadata "placement/availability-zone")
IMAGE_ID=$(metadata ami-id)
INSTANCE_ID=$(metadata instance-id)
HOSTNAME=$(hostname)
EOF

exit 0
