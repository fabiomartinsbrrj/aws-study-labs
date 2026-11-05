# Runbook

## Workstation recriada
O disco se perde. Reclone o repo, rode `terraform init -backend-config=bucket=aws-lab-tfstate-<ACCOUNT_ID>` na pasta do lab. O state esta no S3, nao na maquina.

## Boundary bloqueou algo legitimo
Edite `bootstrap/boundary.tf` no WSL (usuario `admin`) e rode `make apply STACK=bootstrap`. Limite do IAM: a policy tem ~6000 de 6144 caracteres; se estourar, remova regras redundantes antes de adicionar.

## Orcamento estourou
Pare a workstation, rode o dry-run do nuke, destrua labs com `make destroy STACK=labs/<nome>`.

## State corrompido
O bucket tem versionamento: restaure a versao anterior de `<stack>/terraform.tfstate` no S3.
