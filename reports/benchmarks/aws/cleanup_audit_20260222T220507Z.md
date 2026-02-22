# NotDynamo EKS Cleanup Audit

- Status: **WARN**
- Timestamp (UTC): 2026-02-22T22:05:07Z
- Cluster: `notdynamo-eks`
- Region: `us-west-2`
- Image repo: `notdynamo/notdynamo`
- Expect ECR absent: `false`

## Counts

| Check | Count |
|---|---|
| EKS cluster exists | false |
| EC2 instances | 0 |
| EBS volumes | 0 |
| ELBv2 load balancers | 0 |
| Classic ELB load balancers | 0 |
| CloudFormation stacks (eksctl prefix) | 0 |
| ECR repo exists | true |

## Artifacts

- JSON report: `reports/benchmarks/aws/cleanup_audit_20260222T220507Z.json`
- Markdown report: `reports/benchmarks/aws/cleanup_audit_20260222T220507Z.md`
