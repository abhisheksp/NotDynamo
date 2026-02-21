# NotDynamo Single-AZ Benchmark Index

Timestamp (UTC): 2026-02-19T09:00:15Z

## Canonical Artifacts

- Lockstep summary JSON: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.json`
- Lockstep summary Markdown: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.md`
- Lockstep summary CSV: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z.csv`
- Lockstep run root: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs`
- Point n=11: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/lockstep_n11.json`
- Point n=29: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/lockstep_n29.json`
- Point n=35: `reports/benchmarks/aws/e43_lockstep_isolated_fast_20260219T082041Z_runs/lockstep_n35.json`
- Latest in-cluster benchmark JSON: `reports/benchmarks/aws/e2e_http_incluster_latest.json`
- Latest in-cluster benchmark Markdown: `reports/benchmarks/aws/e2e_http_incluster_latest.md`
- Latest benchmark matrix JSON: `reports/benchmarks/aws/benchmark_matrix_latest.json`
- Latest benchmark matrix Markdown: `reports/benchmarks/aws/benchmark_matrix_latest.md`
- Latest scaling sweep JSON: `reports/benchmarks/aws/scaling_sweep_latest.json`
- Latest scaling sweep Markdown: `reports/benchmarks/aws/scaling_sweep_latest.md`
- Lockstep overall status: `PASS`
- Lockstep best point: `n=29 tps=9.96`

## Commands

```bash
IMAGE_REF=<aws-account>.dkr.ecr.us-west-2.amazonaws.com/notdynamo/notdynamo-bench:<tag>
./scripts/eks/eks_lockstep_sweep.sh --name notdynamo-eks --region us-west-2 --nodegroup-name notdynamo-bench-ng --counts 11,29,35 --operations 500 --keyspace 200 --threads 2 --connect-timeout-ms 1000 --request-timeout-ms 1500 --incluster-parallelism 1 --incluster-completions 1 --incluster-bench-node-label notdynamo.io/workload=benchmark --incluster-skip-build --incluster-image "$IMAGE_REF"
./scripts/eks/eks_bench_job_up.sh --name notdynamo-eks --region us-west-2 --operations 500 --keyspace 200 --threads 2 --parallelism 1 --completions 1 --connect-timeout-ms 1000 --request-timeout-ms 1500 --preload false --skip-build --image "$IMAGE_REF" --bench-node-label notdynamo.io/workload=benchmark
```
