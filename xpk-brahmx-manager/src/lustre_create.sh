#!/usr/bin/env bash
# lustre_create.sh - create the managed Lustre instance (one-time)
# run before lustre_setup.sh. skip if instance already exists.
# Usage: bash src/lustre_create.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

echo "==> Creating Lustre instance ${STORAGE_NAME}"
gcloud lustre instances create "${STORAGE_NAME}" \
  --per-unit-storage-throughput="${STORAGE_THROUGHPUT}" \
  --capacity-gib="${STORAGE_CAPACITY}" \
  --filesystem="${STORAGE_FS}" \
  --location="${ZONE}" \
  --network="projects/${PROJECT_ID}/global/networks/${NETWORK_NAME}" \
  --project="${PROJECT_ID}" \
  --async

echo ""
echo "Creation started (async). Wait a few mins then run:"
echo "  gcloud lustre instances describe ${STORAGE_NAME} --location=${ZONE} --project=${PROJECT_ID} --format='value(mountPoint)'"
echo ""
echo "When you see an IP, run lustre_setup.sh"
