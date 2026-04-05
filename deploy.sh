#!/usr/bin/env bash
# deploy.sh — Provision AWS infrastructure and deploy K8S manifests in one shot.
#
# Usage:
#   export KEY_NAME="your-aws-keypair-name"
#   export SSH_KEY_PATH="/path/to/your-key.pem"
#   ./deploy.sh
#
# Optional overrides:
#   AWS_REGION    (default: us-east-1)
#   INSTANCE_TYPE (default: t3.large)
#   GITHUB_USER   — set to your GitHub username if you built your own ISS image
#
# NOTE: The S3 bucket (ygu6ax-data-project-2) is pre-existing and is never
#       created or destroyed by this script.
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

KEY_NAME="${KEY_NAME:-}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.large}"
GITHUB_USER="${GITHUB_USER:-nmagee}"   # default uses the professor's published image

BUCKET_NAME="ygu6ax-data-project-2"
WEBSITE_URL="http://ygu6ax-data-project-2.s3-website-us-east-1.amazonaws.com"

# ─── Preflight checks ────────────────────────────────────────────────────────

for cmd in terraform aws ssh scp; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: '$cmd' not found in PATH"; exit 1; }
done

[[ -z "$KEY_NAME"      ]] && { echo "ERROR: KEY_NAME is not set";      exit 1; }
[[ -z "$SSH_KEY_PATH"  ]] && { echo "ERROR: SSH_KEY_PATH is not set";  exit 1; }
[[ -f "$SSH_KEY_PATH"  ]] || { echo "ERROR: SSH key not found: $SSH_KEY_PATH"; exit 1; }

SSH_OPTS="-i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"

# ─── Terraform — provision all AWS infrastructure ────────────────────────────

echo ""
echo "==> [1/5] Initialising Terraform..."
terraform -chdir=infra init -input=false

echo ""
echo "==> [2/5] Applying Terraform (S3, EC2, EIP, IAM, DynamoDB)..."
terraform -chdir=infra apply -auto-approve \
  -var="key_name=${KEY_NAME}" \
  -var="aws_region=${AWS_REGION}" \
  -var="instance_type=${INSTANCE_TYPE}"

EC2_IP=$(terraform -chdir=infra output -raw ec2_public_ip)

echo ""
echo "    EC2 Elastic IP : $EC2_IP"
echo "    S3 Website URL : $WEBSITE_URL"

# ─── Wait for SSH ────────────────────────────────────────────────────────────

echo ""
echo "==> [3/5] Waiting for SSH on $EC2_IP..."
until ssh $SSH_OPTS ubuntu@"${EC2_IP}" true 2>/dev/null; do
  echo "    ...not ready yet, retrying in 10s"
  sleep 10
done
echo "    SSH is up."

# ─── Wait for K3S ────────────────────────────────────────────────────────────

echo ""
echo "==> [4/5] Waiting for K3S node to become Ready (may take ~2 min)..."
until ssh $SSH_OPTS ubuntu@"${EC2_IP}" \
  "kubectl get nodes 2>/dev/null | grep -q ' Ready'" 2>/dev/null; do
  echo "    ...K3S not ready yet, retrying in 15s"
  sleep 15
done

echo "    K3S cluster status:"
ssh $SSH_OPTS ubuntu@"${EC2_IP}" "kubectl get nodes && kubectl get namespaces"

# ─── Deploy Kubernetes manifests ─────────────────────────────────────────────

echo ""
echo "==> [5/5] Deploying Kubernetes manifests..."

# Patch the ISS job YAML with the chosen GitHub user (in case you built your own image)
sed "s/USERNAME/${GITHUB_USER}/g" iss-job.yaml > /tmp/iss-job-patched.yaml

scp $SSH_OPTS simple-job.yaml /tmp/iss-job-patched.yaml ubuntu@"${EC2_IP}":~/

# Smoke-test: run simple-job, wait for one completion, then clean up
echo ""
echo "    Applying simple-job.yaml (smoke test)..."
ssh $SSH_OPTS ubuntu@"${EC2_IP}" "kubectl apply -f ~/simple-job.yaml"

echo "    Waiting up to 6 min for hello-cronjob to fire..."
DEADLINE=$(( $(date +%s) + 360 ))
until ssh $SSH_OPTS ubuntu@"${EC2_IP}" \
  "kubectl get pods 2>/dev/null | grep hello-cronjob | grep -q Completed" 2>/dev/null; do
  if (( $(date +%s) > DEADLINE )); then
    echo "    WARNING: simple-job did not complete within 6 min — check manually."
    break
  fi
  echo "    ...waiting for hello-cronjob pod, retrying in 20s"
  sleep 20
done

# Print one completed pod's log if available
POD=$(ssh $SSH_OPTS ubuntu@"${EC2_IP}" \
  "kubectl get pods --no-headers 2>/dev/null | grep hello-cronjob | grep Completed | tail -1 | awk '{print \$1}'" 2>/dev/null || true)
if [[ -n "$POD" ]]; then
  echo "    Log from $POD:"
  ssh $SSH_OPTS ubuntu@"${EC2_IP}" "kubectl logs $POD"
fi

echo "    Removing simple-job..."
ssh $SSH_OPTS ubuntu@"${EC2_IP}" "kubectl delete -f ~/simple-job.yaml --ignore-not-found"

# Deploy the ISS tracker
echo ""
echo "    Applying ISS tracker CronJob..."
ssh $SSH_OPTS ubuntu@"${EC2_IP}" "kubectl apply -f ~/iss-job-patched.yaml"

echo ""
echo "    Active CronJobs:"
ssh $SSH_OPTS ubuntu@"${EC2_IP}" "kubectl get cronjobs"

# ─── Done ────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  All done!                                               ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  EC2 IP        : %-39s║\n" "$EC2_IP"
printf "║  SSH           : ssh -i <key>.pem ubuntu@%-18s║\n" "$EC2_IP"
printf "║  Website URL   : %-39s║\n" "$WEBSITE_URL"
printf "║  Plot URL      : %-39s║\n" "${WEBSITE_URL}/plot.png"
printf "║  Data CSV URL  : %-39s║\n" "${WEBSITE_URL}/data.csv"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Build + push your custom data pipeline container"
echo "  2. kubectl apply -f <your-pipeline-job>.yaml"
echo "  3. After 72+ data points, grab the plot URL above for Canvas"
