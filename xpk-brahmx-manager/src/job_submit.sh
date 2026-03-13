#!/usr/bin/env bash
# job_submit.sh — Submit a MaxText pre-training workload to the XPK cluster
# Usage: bash src/job_submit.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

# ─── Job Identity — change these for every new run ────────────────────────────
WORKLOAD_NAME="qwen3-lustre-run-001"     # unique per job
RUN_NAME="qwen3-v6e-lustre-optimized"

# ─── Model Configuration ──────────────────────────────────────────────────────
# qwen3-8b: model_name=qwen3-8b, tokenizer Qwen/Qwen2.5-7B, layers ~32
# gemma3-4b: model_name=gemma3-4b, tokenizer src/maxtext/assets/tokenizers/tokenizer.gemma3, layers 30
MODEL_NAME="qwen3-8b"
BASE_NUM_DECODER_LAYERS=32
TOKENIZER_PATH="Qwen/Qwen2.5-7B"

# ─── Dataset Paths (on Lustre) ────────────────────────────────────────────────
TRAIN_FILES="/lustre-data/data/english_dclm/*.arrayrecord*"
EVAL_FILES="/lustre-data/data/english_dclm/*.arrayrecord*"

# ─── Output ───────────────────────────────────────────────────────────────────
BASE_OUTPUT_DIRECTORY="/lustre-data/${MODEL_NAME}/checkpoints"

# ─── HuggingFace (or set in config.sh) ────────────────────────────────────────
HF_ACCESS_TOKEN="${HF_ACCESS_TOKEN:-YOUR_HUGGINGFACE_TOKEN}"

# ─── Training Hyperparameters ─────────────────────────────────────────────────
PER_DEVICE_BATCH_SIZE=4
MAX_TARGET_LENGTH=4096
GRAIN_WORKER_COUNT=8
GRAIN_PREFETCH_BUFFER_SIZE=20
ATTENTION="flash"
ICI_FSDP_PARALLELISM=-1
REMAT_POLICY="full"
SCAN_LAYERS=True

# ─── XLA / LibTPU Flags (optimized for v6e) ───────────────────────────────────
LIBTPU_INIT_ARGS="--xla_tpu_scoped_vmem_limit_kib=98304 \
--xla_tpu_use_minor_sharding_for_major_trivial_input=true \
--xla_tpu_relayout_group_size_threshold_for_reduce_scatter=1 \
--xla_tpu_assign_all_reduce_scatter_layout=true \
--xla_tpu_enable_data_parallel_all_reduce_opt=true \
--xla_tpu_data_parallel_opt_different_sized_ops=true \
--xla_tpu_enable_async_collective_fusion=true \
--xla_tpu_enable_sparse_core_collective_offload_all_gather=true \
--xla_tpu_enable_sparse_core_collective_offload_reduce_scatter=true \
--xla_tpu_enable_sparse_core_collective_offload_all_reduce=true \
--xla_tpu_host_transfer_overlap_limit=24 \
--xla_tpu_aggressive_opt_barrier_removal=ENABLED \
--xla_lhs_prioritize_async_depth_over_stall=ENABLED \
--xla_latency_hiding_scheduler_rerun=2"

# ─── Validate ─────────────────────────────────────────────────────────────────
if [[ "${HF_ACCESS_TOKEN}" == "YOUR_HUGGINGFACE_TOKEN" ]]; then
  echo "ERROR: HF_ACCESS_TOKEN is not set. Please update it in src/job_submit.sh before running."
  exit 1
fi

echo "==> Submitting workload '${WORKLOAD_NAME}' to cluster '${CLUSTER_NAME}'"
echo "    Model  : ${MODEL_NAME}"
echo "    Run    : ${RUN_NAME}"
echo "    Output : ${BASE_OUTPUT_DIRECTORY}"
echo ""

xpk workload create \
  --cluster "${CLUSTER_NAME}" \
  --workload "${WORKLOAD_NAME}" \
  --tpu-type="${TPU_TYPE}" \
  --reservation="${RESERVATION_NAME}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --docker-image="${DOCKER_IMAGE}" \
  --command=" \
    echo 'Creating output directories...' && \
    mkdir -p ${BASE_OUTPUT_DIRECTORY} && \
    echo 'Starting MaxText pre-training...' && \
    export TENSORSTORE_NUM_THREADS=4 && \
    export LIBTPU_INIT_ARGS='${LIBTPU_INIT_ARGS}' && \
    python3 -m maxtext.trainers.pre_train.train maxtext/configs/base.yml \
      model_name='${MODEL_NAME}' \
      run_name='${RUN_NAME}' \
      dataset_type='grain' \
      grain_train_files='${TRAIN_FILES}' \
      grain_eval_files='${EVAL_FILES}' \
      base_output_directory='${BASE_OUTPUT_DIRECTORY}' \
      tokenizer_path='${TOKENIZER_PATH}' \
      hf_access_token='${HF_ACCESS_TOKEN}' \
      grain_worker_count=${GRAIN_WORKER_COUNT} \
      grain_prefetch_buffer_size=${GRAIN_PREFETCH_BUFFER_SIZE} \
      per_device_batch_size=${PER_DEVICE_BATCH_SIZE} \
      max_target_length=${MAX_TARGET_LENGTH} \
      attention='${ATTENTION}' \
      ici_fsdp_parallelism=${ICI_FSDP_PARALLELISM} \
      remat_policy='${REMAT_POLICY}' \
      decoder_layer_input='offload' \
      query_proj='device' \
      scan_layers=${SCAN_LAYERS} \
      base_num_decoder_layers=${BASE_NUM_DECODER_LAYERS} \
  "

echo ""
echo "Workload '${WORKLOAD_NAME}' submitted successfully."
echo "Monitor with: xpk workload list --cluster ${CLUSTER_NAME} --project ${PROJECT_ID} --zone ${ZONE}"
