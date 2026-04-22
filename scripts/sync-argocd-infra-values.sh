#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <dev|staging|prod>" >&2
  exit 1
fi

ENVIRONMENT="$1"

case "$ENVIRONMENT" in
  dev|staging|prod)
    ;;
  *)
    echo "Unsupported environment: $ENVIRONMENT" >&2
    echo "Expected one of: dev, staging, prod" >&2
    exit 1
    ;;
esac

for cmd in terragrunt jq awk mktemp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VPC_DIR="$REPO_ROOT/terraform/environments/$ENVIRONMENT/vpc"
IAM_DIR="$REPO_ROOT/terraform/environments/$ENVIRONMENT/iam"
VALUES_FILE="$REPO_ROOT/argocd/apps/values-$ENVIRONMENT.yaml"

if [[ ! -d "$VPC_DIR" ]]; then
  echo "Missing Terragrunt VPC directory: $VPC_DIR" >&2
  exit 1
fi

if [[ ! -d "$IAM_DIR" ]]; then
  echo "Missing Terragrunt IAM directory: $IAM_DIR" >&2
  exit 1
fi

if [[ ! -f "$VALUES_FILE" ]]; then
  echo "Missing Argo values file: $VALUES_FILE" >&2
  exit 1
fi

vpc_output="$(cd "$VPC_DIR" && terragrunt output -json)"
iam_output="$(cd "$IAM_DIR" && terragrunt output -json)"

vpc_id="$(printf '%s' "$vpc_output" | jq -r '.vpc_id.value')"
alb_role_arn="$(printf '%s' "$iam_output" | jq -r '.alb_controller_role_arn.value')"
external_secrets_role_arn="$(printf '%s' "$iam_output" | jq -r '.external_secrets_role_arn.value')"
cluster_autoscaler_role_arn="$(printf '%s' "$iam_output" | jq -r '.cluster_autoscaler_role_arn.value')"
jenkins_role_arn="$(printf '%s' "$iam_output" | jq -r '.jenkins_role_arn.value')"

for value_name in \
  vpc_id \
  alb_role_arn \
  external_secrets_role_arn \
  cluster_autoscaler_role_arn \
  jenkins_role_arn; do
  if [[ -z "${!value_name}" || "${!value_name}" == "null" ]]; then
    echo "Failed to resolve required Terragrunt output: $value_name" >&2
    exit 1
  fi
done

tmp_file="$(mktemp)"

awk \
  -v vpc_id="$vpc_id" \
  -v alb_role_arn="$alb_role_arn" \
  -v external_secrets_role_arn="$external_secrets_role_arn" \
  -v cluster_autoscaler_role_arn="$cluster_autoscaler_role_arn" \
  -v jenkins_role_arn="$jenkins_role_arn" '
    /- name: aws-load-balancer-controller/ { app = "alb" }
    /- name: cluster-autoscaler/ { app = "cluster-autoscaler" }
    /- name: external-secrets/ { app = "external-secrets" }
    /- name: jenkins/ { app = "jenkins" }
    /- name: metrics-server/ { app = "metrics-server" }
    /- name: backend/ { app = "backend" }
    /- name: frontend/ { app = "frontend" }
    /- name: mongodb/ { app = "mongodb" }
    /- name: redis/ { app = "redis" }

    app == "alb" && /^[[:space:]]+vpcId:/ {
      sub(/:.*/, ": " vpc_id)
    }

    app == "alb" && /^[[:space:]]+eks\.amazonaws\.com\/role-arn:/ {
      sub(/:.*/, ": " alb_role_arn)
    }

    app == "cluster-autoscaler" && /^[[:space:]]+eks\.amazonaws\.com\/role-arn:/ {
      sub(/:.*/, ": " cluster_autoscaler_role_arn)
    }

    app == "external-secrets" && /^[[:space:]]+eks\.amazonaws\.com\/role-arn:/ {
      sub(/:.*/, ": " external_secrets_role_arn)
    }

    app == "jenkins" && /^[[:space:]]+eks\.amazonaws\.com\/role-arn:/ {
      sub(/:.*/, ": " jenkins_role_arn)
    }

    { print }
  ' "$VALUES_FILE" > "$tmp_file"

mv "$tmp_file" "$VALUES_FILE"

echo "Updated $VALUES_FILE"
echo "  vpcId: $vpc_id"
echo "  albControllerRoleArn: $alb_role_arn"
echo "  externalSecretsRoleArn: $external_secrets_role_arn"
echo "  clusterAutoscalerRoleArn: $cluster_autoscaler_role_arn"
echo "  jenkinsRoleArn: $jenkins_role_arn"
