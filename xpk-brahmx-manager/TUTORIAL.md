# Qwen 3 8B Pre-training on XPK + MaxText + Lustre

Tutorial for running distributed pre-training on TPU v6e with Lustre storage. Uses cluster name `brahmx-v6e-cluster` so you dont collide with others. If something fails, check the Debug section at the bottom.

## Prereqs

- gcloud CLI installed and logged in
- Docker
- Python 3
- GCP project with TPU quota and Lustre enabled

## Step 0: Edit config

```bash
cd xpk-brahmx-manager
```

Edit `src/config.sh`:

- `PROJECT_ID` - your GCP project
- `RESERVATION_NAME` - your TPU reservation (e.g. from DWS calendar)
- `NETWORK_NAME` - VPC name (default or your custom one)
- `STORAGE_NAME`, `STORAGE_FS` - change if you want unique Lustre names

`PROJECT_NUMBER` is auto-fetched if left empty.

## Step 1: Network prep (one-time per project)

Lustre talks to GKE over VPC peering. Run:

```bash
bash src/network_prep.sh
```

## Step 2: Create Lustre instance (one-time)

```bash
bash src/lustre_create.sh
```

Wait until the instance is ready (can take 10-20 mins). Check:

```bash
gcloud lustre instances describe ${STORAGE_NAME} --location=${ZONE} --project=${PROJECT_ID} --format='value(mountPoint)'
```

When you get an IP back, continue.

## Step 3: Create cluster

```bash
bash src/setup.sh
```

If you see:

```
ERROR: Aggregate Reservation '...' does not have a matching accelerator for 'ct6e'
```

the cluster may have been created but without nodes. Run:

```bash
bash src/add_nodepool_manual.sh
```

Then skip to Step 4.

## Step 4: Attach Lustre to cluster

```bash
bash src/lustre_setup.sh
```

This writes the manifest and runs `xpk storage attach`. Workloads will get `/lustre-data` auto-mounted.

## Step 5: Build and push Docker image

```bash
bash src/build_image.sh
```

Uses MaxText TPU Dockerfile. First run can take a while.

## Step 6: Prepare dataset on Lustre

Data must live at `/lustre-data/data/english_dclm/` (or whatever path you set in job_submit.sh). Options:

**A. Sync from GCS** - run a one-off job that copies from your GCS bucket into Lustre, e.g.:

```bash
# example: if you have c4 or similar in gs://your-bucket/
xpk workload create \
  --cluster brahmx-v6e-cluster \
  --workload data-sync \
  --tpu-type=v6e-16 \
  --num-slices=1 \
  --project=${PROJECT_ID} \
  --zone=${ZONE} \
  --docker-image=google/cloud-sdk:slim \
  --command="gsutil -m cp -r gs://your-bucket/your-data/* /lustre-data/data/english_dclm/"
```

**B. Pre-loaded** - if data is already on Lustre, just point `grain_train_files` and `grain_eval_files` in job_submit.sh to the right paths.

## Step 7: Submit training job

Edit `src/job_submit.sh`:

- `HF_ACCESS_TOKEN` - your HuggingFace token
- `MODEL_NAME` - e.g. qwen3-8b, gemma3-4b
- `TRAIN_FILES`, `EVAL_FILES` - paths on Lustre
- `TOKENIZER_PATH` - e.g. Qwen/Qwen2.5-7B for Qwen3

Then:

```bash
bash src/job_submit.sh
```

## Step 8: Monitor

```bash
# list workloads
xpk workload list --cluster brahmx-v6e-cluster --project ${PROJECT_ID} --zone ${ZONE}

# get head pod and tail logs
POD_NAME=$(kubectl get pods -l xpk.google.com/workload=YOUR_WORKLOAD_NAME,batch.kubernetes.io/job-completion-index=0 -o name | head -n 1)
kubectl logs $POD_NAME -c jax-tpu -f
```

Replace `YOUR_WORKLOAD_NAME` with the value from `WORKLOAD_NAME` in job_submit.sh.

---

## Debug

### Pods stuck in ContainerCreating

Lustre CSI driver may not be running:

```bash
kubectl get pods -A | grep lustre
```

You want `lustre-csi-node-*` in Running. If not:

```bash
gcloud container clusters update ${CLUSTER_NAME} \
  --location=${REGION} \
  --project=${PROJECT_ID} \
  --update-addons=LustreCsiDriver=ENABLED
```

### Reservation / accelerator mismatch

Use `add_nodepool_manual.sh` after cluster create fails. Then run `lustre_setup.sh` and `cluster adapt`.

### Wrong network

If Lustre or GKE cant reach each other, confirm:

- VPC peering is active
- Firewall allows tcp 988 and 6988 from 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
- Lustre instance uses the same network as the cluster

### Artifact Registry region mismatch

`build_image.sh` uses `REGION` for the repo. If your image is in a different region, update `DOCKER_IMAGE` in config.sh to match (e.g. us-central1 vs asia-south1).

### Cleanup

```bash
# delete workload
xpk workload delete --workload YOUR_WORKLOAD_NAME --cluster brahmx-v6e-cluster --project ${PROJECT_ID} --zone ${ZONE}

# delete cluster
xpk cluster delete --cluster=brahmx-v6e-cluster --project=${PROJECT_ID} --zone=${ZONE}
```

Lustre instance and data persist. Delete separately if needed:

```bash
gcloud lustre instances delete ${STORAGE_NAME} --location=${ZONE} --project=${PROJECT_ID}
```
