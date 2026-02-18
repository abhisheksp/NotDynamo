# AWS Benchmark Reports

This folder stores EKS benchmark artifacts for NotDynamo.

## Categories

1. External client via port-forward:
   - generator runs on your workstation
   - path includes Kubernetes API + `kubectl port-forward`
   - files: `e2e_http_external_*.json|md` (or legacy `e2e_http_*.json|md`)

2. External client via LoadBalancer/NLB:
   - generator runs on your workstation
   - path includes managed LB ingress hop
   - files: `e2e_http_external_lb_*.json|md`

3. In-cluster benchmark job:
   - generator runs as Kubernetes Job pods inside EKS
   - path stays inside cluster/VPC data path
   - files: `e2e_http_incluster_*.json|md`
   - pod logs: `reports/benchmarks/aws/incluster_runs/<job-name>/*.log`

4. Matrix summary:
   - one report for both categories in a single run
   - files: `benchmark_matrix_*.json|md`

5. Horizontal scaling sweep:
   - scales nodegroup + data replicas across configured combinations
   - stores per-run matrix reports and aggregated sweep summary
   - files: `scaling_sweep_*.json|md|csv`
   - run artifacts: `scaling_sweep_*_runs/run_*/benchmark_matrix.json|md`

## Generators

- `scripts/eks/eks_bench_http.sh`
- `scripts/eks/eks_bench_job_up.sh`
- `scripts/eks/eks_bench_matrix.sh`
- `scripts/eks/eks_scaling_sweep.sh`
