#!/usr/bin/env bash
# setup.sh — Full environment setup and cluster creation for MaxText on TPU
# Usage: bash src/setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

# ─── Validate / derive PROJECT_NUMBER ─────────────────────────────────────────
if [[ -z "${PROJECT_NUMBER:-}" ]]; then
  echo "PROJECT_NUMBER not set, fetching from gcloud..."
  PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)' 2>/dev/null || true)
  if [[ -z "${PROJECT_NUMBER}" ]]; then
    echo "ERROR: Could not get PROJECT_NUMBER. Run: gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)'"
    exit 1
  fi
  export PROJECT_NUMBER
fi

# ─── Step 1: Workspace ────────────────────────────────────────────────────────
echo "==> [1/5] Setting up workspace at ${WORKSPACE_DIR}"
mkdir -p "${WORKSPACE_DIR}"
cd "${WORKSPACE_DIR}"

# ─── Step 2: Clone repositories ───────────────────────────────────────────────
echo "==> [2/5] Cloning repositories"
if [[ ! -d "maxtext" ]]; then
  git clone "${GITHUB_MAXTEXT}"
else
  echo "    maxtext already cloned, skipping."
fi

if [[ ! -d "xpk" ]]; then
  git clone "${GITHUB_XPK}"
else
  echo "    xpk already cloned, skipping."
fi

# ─── Step 3: Python virtual environment ───────────────────────────────────────
echo "==> [3/5] Setting up Python virtual environment"
if [[ ! -d "${VENV_DIR}" ]]; then
  python3 -m venv "${VENV_DIR}"
fi
# shellcheck source=/dev/null
source "${VENV_DIR}/bin/activate"

pip install --quiet xpk/
echo "    XPK installed: $(xpk --version 2>/dev/null || echo 'ok')"

# ─── Step 4: Create XPK cluster ───────────────────────────────────────────────
echo "==> [4/5] Creating XPK cluster"
xpk cluster create \
  --cluster "${CLUSTER_NAME}" \
  --tpu-type="${TPU_TYPE}" \
  --num-slices=1 \
  --reservation="${RESERVATION_NAME}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  --project-number="${PROJECT_NUMBER}" \
  --enable-lustre-csi-driver \
  --skip-validation \
  --custom-cluster-arguments="--network=${NETWORK_NAME} --release-channel=None"

# ─── Step 5: Verify Lustre instance ───────────────────────────────────────────
echo "==> [5/5] Fetching Lustre mount point for '${STORAGE_NAME}'"
LUSTRE_MOUNT_POINT=$(gcloud lustre instances describe "${STORAGE_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="value(mountPoint)")

if [[ -z "${LUSTRE_MOUNT_POINT}" ]]; then
  echo "ERROR: Could not retrieve mount point for Lustre instance '${STORAGE_NAME}'."
  exit 1
fi

echo ""
echo "Cluster '${CLUSTER_NAME}' is ready for job submission."
echo "Lustre mount point: ${LUSTRE_MOUNT_POINT}"
