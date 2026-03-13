#!/usr/bin/env bash
# config.sh — Single source of truth for all shared variables.
# Sourced by setup.sh, lustre_setup.sh, build_image.sh, and job_submit.sh.
# DO NOT run this file directly.

# ─── GCP Project ──────────────────────────────────────────────────────────────
export PROJECT_ID="zenteiq-lxp-1722918338008"
export PROJECT_NUMBER=""   # run: gcloud projects describe $PROJECT_ID --format='value(projectNumber)'
export REGION="asia-south1"
export ZONE="asia-south1-b"

# ─── Cluster ──────────────────────────────────────────────────────────────────
# use a unique name so you dont collide with other peoples clusters
export CLUSTER_NAME="brahmx-v6e-cluster"
export RESERVATION_NAME="ghostlite-pod-l35bufasa705n"
export TPU_TYPE="v6e-16"
export NETWORK_NAME="zenteiq-tpu-vpc"

# ─── Docker / Artifact Registry ───────────────────────────────────────────────
export DOCKER_IMAGE="asia-south1-docker.pkg.dev/${PROJECT_ID}/images/maxtext-v6e:latest"

# ─── Source Repositories ──────────────────────────────────────────────────────
export GITHUB_MAXTEXT="https://github.com/AI-Hypercomputer/maxtext.git"
export GITHUB_XPK="https://github.com/google/xpk.git"

# ─── Lustre Storage ───────────────────────────────────────────────────────────
export STORAGE_NAME="ziq-lustre"
export STORAGE_THROUGHPUT=1000     # MBps/TiB performance tier
export STORAGE_CAPACITY=36000      # GiB
export STORAGE_FS="ziqfs"
export IP_RANGE_NAME="lustre-peering-range"

# ─── Local Workspace ──────────────────────────────────────────────────────────
export WORKSPACE_DIR="${HOME}/tpu-training"
export VENV_DIR="${WORKSPACE_DIR}/tpu_env"

# ─── HuggingFace (required for training) ──────────────────────────────────────
# set this before running run.sh
export HF_ACCESS_TOKEN="${HF_ACCESS_TOKEN:-YOUR_HUGGINGFACE_TOKEN}"
