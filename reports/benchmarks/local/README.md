# Local Benchmark Baselines

These files are source-controlled local benchmark baselines for NotDynamo.

## Canonical profile

- Profile file: `scripts/bench/profiles/local_canonical_v1.env`
- Runner script: `scripts/bench/run_local_canonical_profile.sh`
- Scenarios:
  - `cluster-read` (uniform read distribution)
  - `hotkey-zipf` (skewed read distribution)

## Regenerating

```bash
./scripts/bench/run_local_canonical_profile.sh
```

This updates:

- `reports/benchmarks/local/cluster_read.csv`
- `reports/benchmarks/local/cluster_read.json`
- `reports/benchmarks/local/hotkey_zipf.csv`
- `reports/benchmarks/local/hotkey_zipf.json`
- `reports/benchmarks/local/summary.json`
