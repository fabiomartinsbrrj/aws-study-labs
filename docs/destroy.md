# Desmontar tudo

Rode no WSL com o usuario IAM admin. Ordem importa: o que depende do state do bucket vem antes dele.

## Custo: o que para o gasto
O passo 2 (`bootstrap`) remove a EC2 e o disco, que e o unico custo relevante (~US$12/mes ligada, ~US$1,6 parada).

## 1. Labs (primeiro!)
Um lab de pe usa a boundary `aws-lab-boundary` nas suas roles; se o `bootstrap` for destruido antes, a policy nao pode ser apagada. Rode, para cada lab que exista:

    make destroy STACK=labs/<nome>

Os labs rodam de dentro da workstation; se ela ja nao existe, rode-os do WSL (mesmos comandos).

## 2. Workstation, role, boundary e budget
    make plan STACK=bootstrap ARGS="-destroy"     # confira: so recursos do lab
    make destroy STACK=bootstrap

## 3. Rede
    make destroy STACK=network

## 4. Bucket de state (irreversivel)
So depois dos passos anteriores. O bucket tem `prevent_destroy` e versionamento, entao `terraform destroy` nao serve. O script lista primeiro e so apaga com `--yes`:

    ./scripts/empty-state-bucket.sh          # dry-run: mostra o que seria apagado
    ./scripts/empty-state-bucket.sh --yes    # apaga todas as versoes e o bucket

## 5. Opcional
    aws iam delete-account-alias --account-alias <alias-da-conta>

## O que NAO e apagado
Nada fora do repo: usuarios IAM, buckets e budgets de outros projetos, key pairs e a VPC default da conta.
