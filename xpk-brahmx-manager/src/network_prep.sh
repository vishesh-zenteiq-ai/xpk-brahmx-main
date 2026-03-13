#!/usr/bin/env bash
# network_prep.sh - VPC peering and firewall for Lustre
# run this before creating the cluster. one-time per project/network.
# Usage: bash src/network_prep.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

echo "==> [1/3] Allocating IP range for peering"
if gcloud compute addresses describe "${IP_RANGE_NAME}" --global --project="${PROJECT_ID}" &>/dev/null; then
  echo "    ${IP_RANGE_NAME} already exists, skipping."
else
  gcloud compute addresses create "${IP_RANGE_NAME}" \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=20 \
    --network="${NETWORK_NAME}" \
    --project="${PROJECT_ID}"
fi

echo "==> [2/3] VPC peering"
gcloud services vpc-peerings connect \
  --network="${NETWORK_NAME}" \
  --ranges="${IP_RANGE_NAME}" \
  --service=servicenetworking.googleapis.com \
  --project="${PROJECT_ID}" 2>/dev/null || echo "    peering may already exist"

echo "==> [3/3] Firewall rules for Lustre (988, 6988)"
if gcloud compute firewall-rules describe allow-lustre-all-internal --project="${PROJECT_ID}" &>/dev/null; then
  echo "    allow-lustre-all-internal already exists, skipping."
else
  gcloud compute firewall-rules create allow-lustre-all-internal \
    --allow=tcp:988,tcp:6988 \
    --network="${NETWORK_NAME}" \
    --source-ranges="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16" \
    --project="${PROJECT_ID}"
fi

echo ""
echo "Network prep done. You can run setup.sh now."
