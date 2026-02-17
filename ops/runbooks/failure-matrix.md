# NotDynamo Failure Matrix

This runbook lists the primary failure modes, how to inject each failure, and what correctness property must hold.

## Preconditions

- Local cluster deployed:
  - `./scripts/local/kind_up.sh --name notdynamo --workers 2 --provider nerdctl`
  - `./scripts/local/kind_deploy.sh --name notdynamo --data-replicas 3 --provider nerdctl`
- Namespace: `notdynamo`

## Failure Modes and Verifications

| Failure Mode | Injection Method | Verification Command | Correctness Invariant |
| --- | --- | --- | --- |
| Single data pod crash/restart | Kubernetes pod delete | `./scripts/local/kind_failure_pod_restart.sh --namespace notdynamo --failed-pod notdynamo-data-0` | Cluster remains available and cross-node PUT/GET/DELETE still succeeds after pod recovery |
| Cross-node routing regression | No failure; direct multi-pod request path | `./scripts/local/kind_cross_node_smoke.sh --namespace notdynamo` | PUT via one pod and GET via another returns same value |
| Node drain workflow safety | Kubernetes drain dry run | `./scripts/k8s/drill-node-drain.sh --dry-run --node <node-name> --namespace notdynamo` | Drain command is generated and operator can perform controlled eviction sequence |
| Pod failure drill script safety | Kubernetes delete pod dry run | `./scripts/k8s/drill-pod-delete.sh --dry-run --namespace notdynamo --pod notdynamo-data-0` | Pod delete + readiness wait steps are valid before live run |
| Live gRPC distributed routing | In-test live gRPC cluster | `./gradlew :it:test --tests "io.notdynamo.it.LiveGrpcRoutingIT"` | Requests forwarded across nodes over gRPC preserve KV semantics |
| Live HTTP->gRPC distributed path | In-test live HTTP + gRPC cluster | `./gradlew :it:test --tests "io.notdynamo.it.LiveHttpRoutingIT"` | External HTTP request path routes correctly across nodes |
| Leader failover logic (raft simulation) | Simulated leader unavailability | `./gradlew :raft-ratis:test --tests "io.notdynamo.raft.LeaderFailoverIT"` | New leader can accept writes in higher term |
| Minority partition write safety (raft simulation) | Simulated peer unavailability | `./gradlew :raft-ratis:test --tests "io.notdynamo.raft.PartitionSafetyIT"` | Minority partition cannot commit writes |
| Quorum write behavior (raft simulation) | Simulated quorum/non-quorum acks | `./gradlew :raft-ratis:test --tests "io.notdynamo.raft.QuorumWriteIT"` | 2/3 ack commits, < quorum fails |
| AZ failure behavior (simulation) | In-memory transport unregister | `./gradlew :it:test --tests "io.notdynamo.it.AzFailureSimulationIT"` | Healthy shards remain available; failed shard reports unavailable |

## Gate Commands

- `./scripts/verify/g10.sh`
- `./scripts/verify/g11.sh`
- `./scripts/verify/g12.sh`
- `./scripts/verify/g13.sh`

These gates provide repeatable verification artifacts in `/reports`.
