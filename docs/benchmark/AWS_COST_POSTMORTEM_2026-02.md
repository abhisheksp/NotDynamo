# NotDynamo AWS Cost Postmortem (February 2026)

## Context

This project used EKS lockstep scaling and write/read benchmark sweeps with higher node counts (`N=11..35`) in `us-west-2`.

The expected mental model was "keep daily spend near `$20` with `--max-daily-usd 20`".
Actual AWS usage charges for Feb 2026 were much higher.

## What happened

AWS Cost Explorer (`RECORD_TYPE=Usage`) for `2026-02-01` to `2026-03-01`:

- Total usage: `$453.0896`
- `EC2 - Other`: `$378.0791`
- `Amazon EKS`: `$38.3116`
- `EC2 Compute`: `$32.8873`
- Other services: small

Dominant root cause inside `EC2 - Other`:

- `InterZone-In`: `$178.6940`
- `InterZone-Out`: `$178.6949`
- InterZone total: `$357.3889` (about `78.9%` of total Feb usage)

Other contributors in `EC2 - Other`:

- EBS volumes (`gp2 + gp3`): `$12.8256`
- NAT gateway hours: `$4.9050`
- T3 CPU credits: `$2.9584`

Peak daily usage:

- `2026-02-20`: `$123.3732`
- `2026-02-21`: `$123.4810`
- `2026-02-22`: `$160.9196`

InterZone cost dominated those spike days.

## Why the guardrail did not cap invoice spend

`scripts/eks/eks_up.sh` cost check estimates only:

- EKS control-plane hourly cost
- node hourly price (`nodes-max`)
- root EBS estimate

It does not include:

- inter-AZ transfer (`EC2 - Other: InterZone-*`)
- NAT data processing
- CPU credit charges
- support and tax

So `--max-daily-usd` is a useful preflight compute estimate, but not a hard full-billing ceiling.

## Important observation about topology

In EKS, worker nodes are spread across AZs for fault tolerance.
With distributed write traffic (forwarding + Raft replication + benchmark traffic), that can create large cross-AZ traffic volumes and cost.

## Preventive controls for future runs

1. Treat `--max-daily-usd` as compute-only guidance, not a spend cap.
2. Prefer single-AZ benchmark topology when cost control is primary.
3. Keep benchmark sessions short and tear down cluster immediately after runs.
4. Set AWS Billing alarms/budgets independently of script-side estimates.
5. Run periodic Cost Explorer checks during long sweeps (daily and by `SERVICE` + `USAGE_TYPE`).
6. Keep benchmark generator placement intentional to avoid unnecessary cross-AZ traffic.

## Notes

- Cost Explorer also shows a separate Feb refund line item (`Refund: -$453.09`).
- The values above are usage-side charges and are the correct basis for operational cost diagnosis.
