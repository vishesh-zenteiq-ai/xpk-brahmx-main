#!/usr/bin/env bash
# run.sh - clone, config, then run this. does full pipeline: network, lustre, cluster, attach, build, train
# Usage: ./run.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${REPO_ROOT}/src"
# shellcheck source=src/config.sh
source "${SRC}/config.sh"

echo "=========================================="
echo "xpk-brahmx full pipeline"
echo "=========================================="

# preflight
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1 | grep -q .; then
  echo "Run: gcloud auth login && gcloud auth application-default login"
  exit 1
fi
# edit src/config.sh: PROJECT_ID, RESERVATION_NAME, HF_ACCESS_TOKEN
if [[ "${HF_ACCESS_TOKEN:-}" == "YOUR_HUGGINGFACE_TOKEN" ]] || [[ -z "${HF_ACCESS_TOKEN:-}" ]]; then
  echo "Set HF_ACCESS_TOKEN in src/config.sh before running."
  exit 1
fi

if [[ -z "${PROJECT_NUMBER:-}" ]]; then
  export PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)' 2>/dev/null || true)
  [[ -z "${PROJECT_NUMBER}" ]] && { echo "Could not get PROJECT_NUMBER for ${PROJECT_ID}"; exit 1; }
fi

# 1. network
echo ""
echo "[1/6] Network prep"
bash "${SRC}/network_prep.sh"

# 2. lustre - create if missing, wait until ready
echo ""
echo "[2/6] Lustre"
MOUNT_PT=$(gcloud lustre instances describe "${STORAGE_NAME}" --location="${ZONE}" --project="${PROJECT_ID}" --format='value(mountPoint)' 2>/dev/null || true)
if [[ -z "${MOUNT_PT}" ]]; then
  echo "Creating Lustre instance (async)..."
  gcloud lustre instances create "${STORAGE_NAME}" \
    --per-unit-storage-throughput="${STORAGE_THROUGHPUT}" \
    --capacity-gib="${STORAGE_CAPACITY}" \
    --filesystem="${STORAGE_FS}" \
    --location="${ZONE}" \
    --network="projects/${PROJECT_ID}/global/networks/${NETWORK_NAME}" \
    --project="${PROJECT_ID}" \
    --async
  echo "Waiting for Lustre (polling every 90s, up to 25 min)..."
  for i in $(seq 1 17); do
    sleep 90
    MOUNT_PT=$(gcloud lustre instances describe "${STORAGE_NAME}" --location="${ZONE}" --project="${PROJECT_ID}" --format='value(mountPoint)' 2>/dev/null || true)
    [[ -n "${MOUNT_PT}" ]] && break
    echo "  still waiting... ($((i*90))s)"
  done
  [[ -z "${MOUNT_PT}" ]] && { echo "Lustre not ready. Re-run later."; exit 1; }
fi
echo "Lustre ready: ${MOUNT_PT}"

# 3. cluster
echo ""
echo "[3/6] Cluster"
if gcloud container clusters describe "${CLUSTER_NAME}" --zone="${ZONE}" --project="${PROJECT_ID}" &>/dev/null; then
  echo "Cluster exists, skipping create."
else
  if ! bash "${SRC}/setup.sh" 2>&1 | tee /tmp/xpk-setup.log; then
    if grep -q "matching accelerator" /tmp/xpk-setup.log 2>/dev/null; then
      echo "Reservation error - adding nodepool manually"
      bash "${SRC}/add_nodepool_manual.sh"
    else
      exit 1
    fi
  fi
fi

# 4. lustre attach
echo ""
echo "[4/6] Attach Lustre"
SKIP_INTERACTIVE_AUTH=1 bash "${SRC}/lustre_setup.sh"

# 5. build image
echo ""
echo "[5/6] Build and push image"
bash "${SRC}/build_image.sh"

# 6. submit job
echo ""
echo "[6/6] Submit training"
bash "${SRC}/job_submit.sh"

echo ""
echo "Done. Monitor: kubectl logs -l xpk.google.com/workload=qwen3-lustre-run-001,batch.kubernetes.io/job-completion-index=0 -c jax-tpu -f"
echo ""
echo "If training fails with 'no files' or 'file not found', sync data to /lustre-data/data/english_dclm/ first."
