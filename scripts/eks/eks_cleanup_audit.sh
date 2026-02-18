#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CLUSTER_NAME="${NOTDYNAMO_EKS_CLUSTER:-notdynamo-eks}"
REGION="${AWS_REGION:-us-west-2}"
IMAGE_REPO="notdynamo/notdynamo"
EXPECT_ECR_ABSENT=false

OUTPUT_FILE=""
HUMAN_REPORT_FILE=""

usage() {
  cat <<'USAGE'
Usage: eks_cleanup_audit.sh [options]

Checks for potentially billable AWS resources after teardown and writes JSON + Markdown reports.

Options:
  --name <cluster-name>          EKS cluster name (default: notdynamo-eks)
  --region <aws-region>          AWS region (default: AWS_REGION or us-west-2)
  --image-repo <repo>            ECR repository to check (default: notdynamo/notdynamo)
  --expect-ecr-absent <bool>     true|false (default: false)
  --output-file <path>           JSON output path
  --human-report-file <path>     Markdown output path
  --help                         Show this help
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --image-repo)
      IMAGE_REPO="$2"
      shift 2
      ;;
    --expect-ecr-absent)
      EXPECT_ECR_ABSENT="$2"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --human-report-file)
      HUMAN_REPORT_FILE="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

case "$EXPECT_ECR_ABSENT" in
  true|false)
    ;;
  *)
    echo "--expect-ecr-absent must be true or false" >&2
    exit 1
    ;;
esac

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

to_repo_relative() {
  local path="$1"
  if [[ "$path" == "$ROOT_DIR/"* ]]; then
    echo "${path#"$ROOT_DIR/"}"
  elif [[ "$path" == "$ROOT_DIR" ]]; then
    echo "."
  else
    echo "$path"
  fi
}

text_to_json_array() {
  local input="$1"
  printf '%s\n' "$input" | jq -R -s 'split("\n") | map(select(length > 0))'
}

collect_elbv2_for_cluster() {
  local tag_key="kubernetes.io/cluster/${CLUSTER_NAME}"
  local -a matches=()
  local arn=""
  local tag_value=""

  while IFS= read -r arn; do
    [[ -z "$arn" ]] && continue
    tag_value="$(aws elbv2 describe-tags \
      --region "$REGION" \
      --resource-arns "$arn" \
      --query "TagDescriptions[0].Tags[?Key==\`${tag_key}\`].Value | [0]" \
      --output text 2>/dev/null || true)"
    if [[ "$tag_value" == "owned" || "$tag_value" == "shared" ]]; then
      matches+=("$arn")
    fi
  done < <(
    aws elbv2 describe-load-balancers \
      --region "$REGION" \
      --query 'LoadBalancers[].LoadBalancerArn' \
      --output text 2>/dev/null | tr '\t' '\n' | awk 'NF'
  )

  printf '%s\n' "${matches[@]:-}"
}

collect_elb_classic_for_cluster() {
  local tag_key="kubernetes.io/cluster/${CLUSTER_NAME}"
  local -a matches=()
  local name=""
  local tag_value=""

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    tag_value="$(aws elb describe-tags \
      --region "$REGION" \
      --load-balancer-names "$name" \
      --query "TagDescriptions[0].Tags[?Key==\`${tag_key}\`].Value | [0]" \
      --output text 2>/dev/null || true)"
    if [[ "$tag_value" == "owned" || "$tag_value" == "shared" ]]; then
      matches+=("$name")
    fi
  done < <(
    aws elb describe-load-balancers \
      --region "$REGION" \
      --query 'LoadBalancerDescriptions[].LoadBalancerName' \
      --output text 2>/dev/null | tr '\t' '\n' | awk 'NF'
  )

  printf '%s\n' "${matches[@]:-}"
}

require_bin aws
require_bin jq
require_bin awk

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not configured or not valid." >&2
  echo "Run: aws configure" >&2
  exit 1
fi

RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_TS_HUMAN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPORT_DIR="$ROOT_DIR/reports/benchmarks/aws"

if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$REPORT_DIR/cleanup_audit_${RUN_TS}.json"
fi
if [[ -z "$HUMAN_REPORT_FILE" ]]; then
  if [[ "$OUTPUT_FILE" == *.json ]]; then
    HUMAN_REPORT_FILE="${OUTPUT_FILE%.json}.md"
  else
    HUMAN_REPORT_FILE="${OUTPUT_FILE}.md"
  fi
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
mkdir -p "$(dirname "$HUMAN_REPORT_FILE")"

CLUSTER_EXISTS=false
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
  CLUSTER_EXISTS=true
fi

INSTANCE_IDS="$(
  aws ec2 describe-instances \
    --region "$REGION" \
    --filters \
      "Name=tag:alpha.eksctl.io/cluster-name,Values=${CLUSTER_NAME}" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text | tr '\t' '\n' | awk 'NF'
)"

EBS_VOLUME_IDS="$(
  aws ec2 describe-volumes \
    --region "$REGION" \
    --filters \
      "Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=owned,shared" \
      "Name=status,Values=creating,available,in-use" \
    --query 'Volumes[].VolumeId' \
    --output text | tr '\t' '\n' | awk 'NF'
)"

ELBV2_ARNS="$(collect_elbv2_for_cluster)"
ELB_CLASSIC_NAMES="$(collect_elb_classic_for_cluster)"

STACK_NAMES="$(
  aws cloudformation list-stacks \
    --region "$REGION" \
    --stack-status-filter \
      CREATE_IN_PROGRESS CREATE_FAILED CREATE_COMPLETE \
      ROLLBACK_IN_PROGRESS ROLLBACK_FAILED ROLLBACK_COMPLETE \
      DELETE_FAILED UPDATE_IN_PROGRESS UPDATE_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_COMPLETE UPDATE_ROLLBACK_IN_PROGRESS UPDATE_ROLLBACK_FAILED UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_ROLLBACK_COMPLETE \
      REVIEW_IN_PROGRESS IMPORT_IN_PROGRESS IMPORT_COMPLETE IMPORT_ROLLBACK_IN_PROGRESS IMPORT_ROLLBACK_FAILED IMPORT_ROLLBACK_COMPLETE \
    --query "StackSummaries[?starts_with(StackName, 'eksctl-${CLUSTER_NAME}')].StackName" \
    --output text | tr '\t' '\n' | awk 'NF'
)"

ECR_REPO_EXISTS=false
if aws ecr describe-repositories --region "$REGION" --repository-names "$IMAGE_REPO" >/dev/null 2>&1; then
  ECR_REPO_EXISTS=true
fi

INSTANCE_IDS_JSON="$(text_to_json_array "$INSTANCE_IDS")"
EBS_VOLUME_IDS_JSON="$(text_to_json_array "$EBS_VOLUME_IDS")"
ELBV2_ARNS_JSON="$(text_to_json_array "$ELBV2_ARNS")"
ELB_CLASSIC_NAMES_JSON="$(text_to_json_array "$ELB_CLASSIC_NAMES")"
STACK_NAMES_JSON="$(text_to_json_array "$STACK_NAMES")"

INSTANCE_COUNT="$(jq -r 'length' <<<"$INSTANCE_IDS_JSON")"
EBS_COUNT="$(jq -r 'length' <<<"$EBS_VOLUME_IDS_JSON")"
ELBV2_COUNT="$(jq -r 'length' <<<"$ELBV2_ARNS_JSON")"
ELB_CLASSIC_COUNT="$(jq -r 'length' <<<"$ELB_CLASSIC_NAMES_JSON")"
STACK_COUNT="$(jq -r 'length' <<<"$STACK_NAMES_JSON")"

STATUS="PASS"
if [[ "$CLUSTER_EXISTS" == "true" ]] || (( INSTANCE_COUNT > 0 )) || (( EBS_COUNT > 0 )) || (( ELBV2_COUNT > 0 )) || (( ELB_CLASSIC_COUNT > 0 )) || (( STACK_COUNT > 0 )); then
  STATUS="FAIL"
fi
if [[ "$EXPECT_ECR_ABSENT" == "true" && "$ECR_REPO_EXISTS" == "true" ]]; then
  STATUS="FAIL"
fi
if [[ "$STATUS" == "PASS" && "$EXPECT_ECR_ABSENT" == "false" && "$ECR_REPO_EXISTS" == "true" ]]; then
  STATUS="WARN"
fi

OUTPUT_FILE_REL="$(to_repo_relative "$OUTPUT_FILE")"
HUMAN_REPORT_REL="$(to_repo_relative "$HUMAN_REPORT_FILE")"

jq -n \
  --arg benchmark "eks_cleanup_audit" \
  --arg status "$STATUS" \
  --arg timestamp_utc "$RUN_TS_HUMAN" \
  --arg cluster_name "$CLUSTER_NAME" \
  --arg region "$REGION" \
  --arg image_repo "$IMAGE_REPO" \
  --arg cluster_exists "$CLUSTER_EXISTS" \
  --arg expect_ecr_absent "$EXPECT_ECR_ABSENT" \
  --arg ecr_repo_exists "$ECR_REPO_EXISTS" \
  --arg report_md "$HUMAN_REPORT_REL" \
  --argjson instances "$INSTANCE_IDS_JSON" \
  --argjson ebs_volumes "$EBS_VOLUME_IDS_JSON" \
  --argjson elbv2 "$ELBV2_ARNS_JSON" \
  --argjson elb_classic "$ELB_CLASSIC_NAMES_JSON" \
  --argjson cfn_stacks "$STACK_NAMES_JSON" \
  '{
    benchmark: $benchmark,
    status: $status,
    timestamp_utc: $timestamp_utc,
    cluster_name: $cluster_name,
    region: $region,
    image_repo: $image_repo,
    checks: {
      cluster_exists: ($cluster_exists == "true"),
      ec2_instances: $instances,
      ebs_volumes: $ebs_volumes,
      elbv2_load_balancers: $elbv2,
      elb_classic_load_balancers: $elb_classic,
      cloudformation_stacks: $cfn_stacks,
      ecr_repo_exists: ($ecr_repo_exists == "true"),
      expect_ecr_absent: ($expect_ecr_absent == "true")
    },
    counts: {
      ec2_instances: ($instances | length),
      ebs_volumes: ($ebs_volumes | length),
      elbv2_load_balancers: ($elbv2 | length),
      elb_classic_load_balancers: ($elb_classic | length),
      cloudformation_stacks: ($cfn_stacks | length)
    },
    human_report: $report_md
  }' >"$OUTPUT_FILE"

{
  echo "# NotDynamo EKS Cleanup Audit"
  echo
  echo "- Status: **$STATUS**"
  echo "- Timestamp (UTC): $RUN_TS_HUMAN"
  echo "- Cluster: \`$CLUSTER_NAME\`"
  echo "- Region: \`$REGION\`"
  echo "- Image repo: \`$IMAGE_REPO\`"
  echo "- Expect ECR absent: \`$EXPECT_ECR_ABSENT\`"
  echo
  echo "## Counts"
  echo
  echo "| Check | Count |"
  echo "|---|---|"
  echo "| EKS cluster exists | $CLUSTER_EXISTS |"
  echo "| EC2 instances | $INSTANCE_COUNT |"
  echo "| EBS volumes | $EBS_COUNT |"
  echo "| ELBv2 load balancers | $ELBV2_COUNT |"
  echo "| Classic ELB load balancers | $ELB_CLASSIC_COUNT |"
  echo "| CloudFormation stacks (eksctl prefix) | $STACK_COUNT |"
  echo "| ECR repo exists | $ECR_REPO_EXISTS |"
  echo
  if (( INSTANCE_COUNT > 0 )) || (( EBS_COUNT > 0 )) || (( ELBV2_COUNT > 0 )) || (( ELB_CLASSIC_COUNT > 0 )) || (( STACK_COUNT > 0 )) || [[ "$CLUSTER_EXISTS" == "true" ]]; then
    echo "## Residual Resources"
    echo
    echo "- EC2 instances: \`$(printf '%s ' $INSTANCE_IDS)\`"
    echo "- EBS volumes: \`$(printf '%s ' $EBS_VOLUME_IDS)\`"
    echo "- ELBv2 ARNs: \`$(printf '%s ' $ELBV2_ARNS)\`"
    echo "- ELB classic names: \`$(printf '%s ' $ELB_CLASSIC_NAMES)\`"
    echo "- CloudFormation stacks: \`$(printf '%s ' $STACK_NAMES)\`"
    echo
  fi
  echo "## Artifacts"
  echo
  echo "- JSON report: \`$OUTPUT_FILE_REL\`"
  echo "- Markdown report: \`$HUMAN_REPORT_REL\`"
} >"$HUMAN_REPORT_FILE"

CLEANUP_LATEST_JSON="$(dirname "$OUTPUT_FILE")/cleanup_audit_latest.json"
CLEANUP_LATEST_MD="$(dirname "$HUMAN_REPORT_FILE")/cleanup_audit_latest.md"
cp "$OUTPUT_FILE" "$CLEANUP_LATEST_JSON"
cp "$HUMAN_REPORT_FILE" "$CLEANUP_LATEST_MD"

echo "EKS cleanup audit complete."
echo "Status: $STATUS"
echo "JSON report: $OUTPUT_FILE_REL"
echo "Markdown report: $HUMAN_REPORT_REL"
echo "Latest JSON: $(to_repo_relative "$CLEANUP_LATEST_JSON")"
echo "Latest Markdown: $(to_repo_relative "$CLEANUP_LATEST_MD")"

if [[ "$STATUS" == "FAIL" ]]; then
  exit 1
fi
