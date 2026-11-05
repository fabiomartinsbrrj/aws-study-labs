#!/usr/bin/env bash
# Uso: nuke/run.sh            -> dry-run (padrao, nao apaga nada)
#      nuke/run.sh --apply    -> apaga de verdade (so depois de ler o dry-run)
set -euo pipefail
cd "$(dirname "$0")"

arn=$(aws sts get-caller-identity --query Arn --output text)
if [[ "$arn" != *":user/"* ]]; then
  echo "Abortado: rode com um usuario IAM admin (atual: $arn). O nuke nunca roda por role/workstation." >&2
  exit 1
fi
[[ -f keep.local.json ]] || { echo "Abortado: crie nuke/keep.local.json (copie keep.local.json.example). Ele lista usuarios, GRUPOS e ROLES que dao acesso a sua conta; sem isso o nuke pode remover o seu proprio acesso." >&2; exit 1; }
export ACCOUNT_ID ADMIN_USER STATE_BUCKET LAB_VPC_ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ADMIN_USER=${arn##*/}
STATE_BUCKET="aws-lab-tfstate-${ACCOUNT_ID}"
LAB_VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=aws-lab --query 'Vpcs[0].VpcId' --output text)
[[ "$LAB_VPC_ID" != "None" ]] || LAB_VPC_ID="vpc-nao-existe"   # lab desmontado: nada a proteger na VPC
python3 render-config.py

args=(run --config .rendered.yml --log-disable-colors)
[[ "${1:-}" == "--apply" ]] || args+=(--no-prompt)   # dry-run nao precisa de confirmacao
if [[ "${1:-}" == "--apply" ]]; then
  alias_now=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text)
  read -r -p "Isso APAGA recursos de verdade. Digite o alias da conta ($alias_now) para continuar: " alias_in
  [[ "$alias_in" == "$alias_now" ]] || { echo "Alias nao confere."; exit 1; }
  args+=(--no-dry-run)
fi
exec aws-nuke "${args[@]}"
