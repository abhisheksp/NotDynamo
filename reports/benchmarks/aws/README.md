# AWS Benchmark Reports

This folder stores EKS benchmark artifacts for NotDynamo.

## Categories

1. External client via port-forward:
   - generator runs on your workstation
   - path includes Kubernetes API + `kubectl port-forward`
   - files: `e2e_http_external_*.json|md` (or legacy `e2e_http_*.json|md`)

2. In-cluster benchmark job:
   - generator runs as Kubernetes Job pods inside EKS
   - path stays inside cluster/VPC data path
   - files: `e2e_http_incluster_*.json|md`
   - pod logs: `reports/benchmarks/aws/incluster_runs/<job-name>/*.log`

3. Matrix summary:
   - one report for both categories in a single run
   - files: `benchmark_matrix_*.json|md`

## Generators

- `scripts/eks/eks_bench_http.sh`
- `scripts/eks/eks_bench_job_up.sh`
- `scripts/eks/eks_bench_matrix.sh`
