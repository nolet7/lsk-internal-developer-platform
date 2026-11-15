#!/usr/bin/env bash
set -euo pipefail
# Run only from a trusted identity with network access and approved change.
: "${AWS_REGION:?Set AWS_REGION}"
: "${TF_DIR:=infra/aws}"
: "${EXECUTE_MIGRATION:=false}"
for program in aws terraform jq; do command -v "$program" >/dev/null || { echo "Missing $program" >&2; exit 1; }; done
cluster=$(terraform -chdir="$TF_DIR" output -raw ecs_cluster_name)
family=$(terraform -chdir="$TF_DIR" output -raw ecs_task_family)
sg=$(terraform -chdir="$TF_DIR" output -raw app_security_group_id)
subnets=$(terraform -chdir="$TF_DIR" output -json private_subnet_ids | jq -c .)
network=$(jq -nc --argjson subnets "$subnets" --arg sg "$sg"   '{awsvpcConfiguration:{subnets:$subnets,securityGroups:[$sg],assignPublicIp:"DISABLED"}}')
overrides='{"containerOverrides":[{"name":"api","command":["python","scripts/migrate.py"]}]}'
echo "Target ECS cluster: $cluster, task definition: $family, region: $AWS_REGION"
if [[ "$EXECUTE_MIGRATION" != "true" ]]; then
  echo "DRY RUN: set EXECUTE_MIGRATION=true only after reviewing backup and Alembic schema diff."
  exit 0
fi
task=$(aws ecs run-task --region "$AWS_REGION" --cluster "$cluster"   --task-definition "$family" --launch-type FARGATE --count 1   --network-configuration "$network" --overrides "$overrides")
failure_count=$(jq '.failures | length' <<< "$task")
[[ "$failure_count" == "0" ]] || { echo "ECS run-task returned failures" >&2; exit 1; }
arn=$(jq -r '.tasks[0].taskArn // empty' <<< "$task")
[[ -n "$arn" ]] || { echo "No migration task created" >&2; exit 1; }
aws ecs wait tasks-stopped --region "$AWS_REGION" --cluster "$cluster" --tasks "$arn"
result=$(aws ecs describe-tasks --region "$AWS_REGION" --cluster "$cluster" --tasks "$arn")
exit_code=$(jq -r '.tasks[0].containers[] | select(.name=="api") | .exitCode // 99' <<< "$result")
[[ "$exit_code" == "0" ]] || { echo "Migration job failed with code $exit_code" >&2; exit 1; }
echo "Alembic migration succeeded in approved AWS environment."
