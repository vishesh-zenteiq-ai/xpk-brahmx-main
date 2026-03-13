#!/usr/bin/env bash
# lustre_setup.sh — Create Lustre manifest and attach storage to XPK cluster
# Run this after setup.sh completes successfully.
# Usage: bash src/lustre_setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

MANIFEST="${SCRIPT_DIR}/manifests/lustre.yaml"

# ─── Step 1: Extract Lustre IP from mountPoint ────────────────────────────────
echo "==> [1/4] Fetching Lustre IP from instance '${STORAGE_NAME}'"
MOUNT_POINT=$(gcloud lustre instances describe "${STORAGE_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="value(mountPoint)")

if [[ -z "${MOUNT_POINT}" ]]; then
  echo "ERROR: Could not retrieve mountPoint for Lustre instance '${STORAGE_NAME}'."
  exit 1
fi

# mountPoint is in the form "IP:/filesystem" — extract just the IP
LUSTRE_IP="${MOUNT_POINT%%:*}"
echo "    Lustre IP: ${LUSTRE_IP}"

# ─── Step 2: Write the manifest ───────────────────────────────────────────────
echo "==> [2/4] Writing manifest to ${MANIFEST}"
mkdir -p "${SCRIPT_DIR}/manifests"

cat > "${MANIFEST}" <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: xpk-lustre-pv
spec:
  storageClassName: ""
  capacity:
    storage: ${STORAGE_CAPACITY}Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  volumeMode: Filesystem
  claimRef:
    namespace: default
    name: xpk-lustre-pvc
  csi:
    driver: lustre.csi.storage.gke.io
    volumeHandle: "projects/${PROJECT_ID}/locations/${ZONE}/instances/${STORAGE_NAME}"
    volumeAttributes:
      ip: "${LUSTRE_IP}"
      filesystem: "${STORAGE_FS}"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: xpk-lustre-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  volumeName: xpk-lustre-pv
  resources:
    requests:
      storage: ${STORAGE_CAPACITY}Gi
EOF

echo "    Manifest written."

# ─── Step 3: Authenticate (skip if SKIP_INTERACTIVE_AUTH=1, e.g. from run.sh) ───
if [[ "${SKIP_INTERACTIVE_AUTH:-0}" != "1" ]]; then
  echo "==> [3/4] Authenticating with Google Cloud"
  gcloud auth login
  gcloud auth application-default login
else
  echo "==> [3/4] Skipping interactive auth (already verified)"
fi

# ─── Step 4: Attach storage to XPK cluster ────────────────────────────────────
echo "==> [4/4] Attaching Lustre storage to cluster '${CLUSTER_NAME}'"
xpk storage attach "${STORAGE_NAME}" \
  --cluster="${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --type=lustre \
  --mount-point='/lustre-data' \
  --readonly=false \
  --auto-mount=true \
  --manifest="${MANIFEST}"

echo ""
echo "Lustre storage '${STORAGE_NAME}' attached to cluster '${CLUSTER_NAME}'."
echo "All future workloads will have it auto-mounted at /lustre-data"
