# Limpeza com aws-nuke

Apaga tudo na conta de estudo, exceto o que tem a tag `persist=true` e o que esta protegido em `nuke-config.yml.tpl` + `keep.local.json`.

`run.sh` renderiza o template com valores descobertos na hora (conta, bucket de state, VPC do lab, usuario admin) e com a sua lista pessoal em `keep.local.json` (ignorado pelo git; veja o `.example`).

1. Pre-requisitos: alias na conta (`aws iam create-account-alias --account-alias <alias>`) e `aws-nuke` instalado, `keep.local.json` criado (fork mantido: ekristen/aws-nuke).
2. `nuke/run.sh` faz so o dry-run. Leia a lista inteira (inclusive o que sobrou de projetos antigos).
3. So depois: `nuke/run.sh --apply`.

O config foi validado por dry-run em 2026-11-05 (aws-nuke v3.69.0): 0 recursos apagaveis apos a limpeza inicial. Rode o dry-run de novo sempre que criar algo novo que deva ser mantido.
Recursos criados via Terraform devem sair por `terraform destroy`, nao pelo nuke.

## Limitacao conhecida: a tag `persist` e confiavel so ate certo ponto
A boundary impede a workstation de definir `persist` em recursos EC2, mas nao em IAM, S3, Logs ou SSM (limite de tamanho da policy). Um recurso marcado assim escaparia da limpeza e continuaria gerando custo.

Mitigacao: no dry-run, confira a lista de recursos *filtrados* contra a base conhecida (state bucket, rede, workstation, role/boundary/profile, budget). Qualquer outro item com `persist=true` merece olhar. Para IAM, a protecao por nome (secao `protected-by-name`) vale mais que a tag.
