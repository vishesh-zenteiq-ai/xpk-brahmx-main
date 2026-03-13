#!/usr/bin/env bash
# build_image.sh — Build and push the MaxText TPU Docker image to Artifact Registry
# One-time / as-needed operation.
# Usage: bash src/build_image.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

MAXTEXT_DIR="${WORKSPACE_DIR}/maxtext"

# ─── Step 1: Create Artifact Registry repository (idempotent) ─────────────────
echo "==> [1/4] Creating Artifact Registry repository (if not exists)"
if ! gcloud artifacts repositories describe images \
     --location="${REGION}" \
     --project="${PROJECT_ID}" &>/dev/null; then
  gcloud artifacts repositories create images \
    --repository-format=docker \
    --location="${REGION}" \
    --description="Docker repository for MaxText TPU training images" \
    --project="${PROJECT_ID}"
  echo "    Repository created."
else
  echo "    Repository already exists, skipping."
fi

# ─── Step 2: Authenticate Docker ──────────────────────────────────────────────
echo "==> [2/4] Configuring Docker authentication for ${REGION}-docker.pkg.dev"
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# ─── Step 3: Build the image ──────────────────────────────────────────────────
echo "==> [3/4] Building Docker image: ${DOCKER_IMAGE}"
if [[ ! -d "${MAXTEXT_DIR}" ]]; then
  echo "ERROR: MaxText directory not found at '${MAXTEXT_DIR}'."
  echo "       Run setup.sh first to clone the repositories."
  exit 1
fi

docker build \
  -t "${DOCKER_IMAGE}" \
  -f "${MAXTEXT_DIR}/dependencies/dockerfiles/maxtext_tpu_dependencies.Dockerfile" \
  "${MAXTEXT_DIR}"

# ─── Step 4: Push the image ───────────────────────────────────────────────────
echo "==> [4/4] Pushing image to Artifact Registry"
docker push "${DOCKER_IMAGE}"

echo ""
echo "Image pushed successfully: ${DOCKER_IMAGE}"
