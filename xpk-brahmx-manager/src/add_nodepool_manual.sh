#!/usr/bin/env bash
# add_nodepool_manual.sh - fallback when cluster create fails with:
#   "Aggregate Reservation does not have a matching accelerator for 'ct6e'"
# common with DWS Calendar reservations. run this then lustre_setup + adapt.
# Usage: bash src/add_nodepool_manual.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

echo "==> Adding TPU node pool manually to ${CLUSTER_NAME}"
gcloud beta container node-pools create tpu-v6e-16-pool \
  --cluster="${CLUSTER_NAME}" \
  --location="${REGION}" \
  --node-locations="${ZONE}" \
  --machine-type=ct6e-standard-4t \
  --tpu-topology=4x4 \
  --reservation-affinity=specific \
  --reservation="${RESERVATION_NAME}" \
  --image-type=cos_containerd \
  --project="${PROJECT_ID}" \
  --scopes="storage-full,cloud-platform"

echo ""
echo "==> Adapting cluster for Lustre CSI"
xpk cluster adapt \
  --cluster="${CLUSTER_NAME}" \
  --tpu-type="${TPU_TYPE}" \
  --num-slices=1 \
  --reservation="${RESERVATION_NAME}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --enable-lustre-csi-driver

echo ""
echo "Node pool added. Run lustre_setup.sh next."
