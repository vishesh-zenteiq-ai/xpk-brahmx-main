# xpk-brahmx

XPK-based setup for MaxText pre-training on TPU v6e with Lustre. Uses cluster name `brahmx-v6e-cluster` to avoid collisions.

## Quick start

```bash
git clone https://github.com/brahmai-model-training/xpk-brahmx.git
cd xpk-brahmx
```

Edit `src/config.sh`: set `PROJECT_ID`, `RESERVATION_NAME`, `HF_ACCESS_TOKEN`, and `NETWORK_NAME` if needed. Then:

```bash
./run.sh
```

That runs the full pipeline (network, Lustre, cluster, attach, build, training). First run can take 30+ min (Lustre creation, image build). For step-by-step or troubleshooting, see [TUTORIAL.md](TUTORIAL.md).

## Layout

- `src/config.sh` - shared config (project, cluster, Lustre, paths)
- `src/network_prep.sh` - VPC peering and firewall
- `src/lustre_create.sh` - create Lustre instance
- `src/setup.sh` - workspace, xpk install, cluster create
- `src/add_nodepool_manual.sh` - fallback when reservation fails
- `src/lustre_setup.sh` - attach Lustre to cluster
- `src/build_image.sh` - build and push MaxText Docker image
- `src/job_submit.sh` - submit training workload

## License

MIT - see LICENSE.
