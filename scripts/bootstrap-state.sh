#!/usr/bin/env bash
# Cria o bucket de state (stack state-backend) e migra o state dela para o proprio bucket.
# Ovo e galinha: o backend S3 so existe depois do apply, entao o primeiro apply usa state local.
set -euo pipefail
cd "$(dirname "$0")/.."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="aws-lab-tfstate-${ACCOUNT_ID}"

if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "O bucket $BUCKET ja existe. Se ainda nao inicializou o backend: make init STACK=state-backend"
  exit 0
fi

cd state-backend
restore() { [[ -f backend.tf.off ]] && mv backend.tf.off backend.tf; return 0; }
trap restore EXIT
mv backend.tf backend.tf.off          # primeiro apply: state local
terraform init -input=false
terraform apply
restore
trap - EXIT
cd ..

# agora o bucket existe: migra o state local para ele
terraform -chdir=state-backend init -backend-config="bucket=${BUCKET}" -migrate-state -force-copy -input=false
rm -f state-backend/terraform.tfstate state-backend/terraform.tfstate.backup
echo "Pronto: state do state-backend esta em s3://${BUCKET}/state-backend/terraform.tfstate"
