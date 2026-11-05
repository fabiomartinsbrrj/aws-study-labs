# aws-study-labs

Laboratório pessoal para **aprender AWS com Terraform**, pensado para subir e destruir infraestrutura sob demanda e não pagar por recurso esquecido.

A peça central é uma **admin workstation**: uma EC2 pequena, com AWS CLI, Terraform e kiro-cli, acessada por SSM (sem abrir porta). De dentro dela você roda os experimentos (`labs/`) usando uma IAM role com limites de segurança e de custo, em vez de chaves de acesso.

> **Atenção:** isto cria recursos que cobram na sua conta AWS (veja [Custo](#custo)). Use uma conta dedicada a estudo e leia o código antes de rodar. O projeto é didático e não foi feito para produção.

## O que tem aqui

| Pasta | Função | Vida útil |
|---|---|---|
| `state-backend/` | Bucket S3 que guarda o state de todas as stacks | permanente |
| `network/` | VPC, 2 subnets públicas, Internet Gateway (sem NAT, que é caro) | permanente |
| `bootstrap/` | Workstation, IAM role + *permissions boundary*, Budget de US$10/mês | permanente |
| `labs/*` | Experimentos, um state por lab (começa com `ec2-basico`) | descartável |
| `nuke/` | Limpeza, com aws-nuke, do que foi criado à mão | sob demanda |
| `docs/` | Design, plano de implementação, runbook e como desmontar | |

Cada pasta é uma stack Terraform independente, com state próprio. Destruir um lab não toca na rede nem na workstation.

## Pré-requisitos

- Conta AWS **dedicada a estudo** e um usuário IAM com permissão de administrador, configurado no AWS CLI (`aws sts get-caller-identity` precisa funcionar).
- Terraform **1.10 ou superior** (usa lock nativo no S3, sem DynamoDB), AWS CLI, `make`, `python3` e `git`.
- [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) para entrar na workstation.
- Um **key pair EC2 já existente** na conta, em `us-east-1` (só o nome é usado; o `.pem` não é lido).
- Região fixa em `us-east-1` (a boundary só aceita essa).

## Como rodar, do zero

```bash
git clone https://github.com/<seu-usuario>/aws-study-labs.git && cd aws-study-labs

# 1. Configuração pessoal (o arquivo fica fora do git)
cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars   # edite key_name e alert_email

# 2. Bucket de state (cria com state local e migra para o próprio bucket)
make bootstrap-state

# 3. Rede e workstation
make init STACK=network   && make apply STACK=network
make init STACK=bootstrap && make apply STACK=bootstrap
```

O `bootstrap` também cria o Budget, com alertas por e-mail para `alert_email`.

### Usar a workstation e rodar um lab

```bash
aws ssm start-session --target $(terraform -chdir=bootstrap output -raw instance_id)

# dentro da workstation:
sudo -iu ec2-user
git clone https://github.com/<seu-usuario>/aws-study-labs.git && cd aws-study-labs
make init STACK=labs/ec2-basico && make apply STACK=labs/ec2-basico
make destroy STACK=labs/ec2-basico        # ao terminar
```

A instalação das ferramentas acontece no primeiro boot (leva alguns minutos).

SSH vem **desligado**. Para ligar, coloque `ssh_cidrs = ["SEU.IP/32"]` no `terraform.tfvars` e aplique de novo o `bootstrap`.

## Limites de segurança e custo

A role da workstation usa uma *permissions boundary* (`bootstrap/boundary.tf`) que, entre outras regras:

- só permite a região `us-east-1` e instâncias `t3.*` / `t4g.*`;
- nega NAT Gateway, EKS e RDS (caros);
- só deixa a workstation criar roles que carreguem a mesma boundary;
- impede que ela altere a si mesma, a boundary ou os states de `bootstrap/`, `network/` e `state-backend/`.

Isso reduz o risco de erro, mas **não é um teto de custo nem uma garantia de segurança**. Ela não limita, por exemplo, tamanho e tipo de volumes EBS, IPs elásticos, VPC endpoints ou o número de instâncias `t3`. O que realmente avisa de gasto é o Budget (com atraso de horas). A policy está perto do limite de tamanho do IAM (6144 caracteres).

## Custo

Valores estimados, não confirmados no pricing da AWS:

| Estado da workstation | Custo por mês |
|---|---|
| Ligada 24h | ~US$12 (instância ~7,5 + IP público ~3,6 + disco ~1,6) |
| Parada | ~US$1,6 (só o disco) |

Pare a instância quando não usar: `aws ec2 stop-instances --instance-ids <id>`. O Budget avisa em 50%, 80% e 100% de US$10.

## Limpeza do que foi criado à mão

`nuke/` apaga o que **não** estiver protegido (tag `persist=true` e a sua lista em `nuke/keep.local.json`). Instale o [aws-nuke](https://github.com/ekristen/aws-nuke), copie `nuke/keep.local.json.example` para `nuke/keep.local.json` e rode `nuke/run.sh`: por padrão é só um dry-run, que lista sem apagar. **Antes do `--apply`, liste em `keep.local.json` tudo o que dá acesso à sua conta** (usuários, grupos como `Administrators`, roles de CI/Organizations): senão o nuke pode remover o seu próprio acesso. Leia [nuke/README.md](nuke/README.md).

## Desmontar tudo

Passo a passo em [docs/destroy.md](docs/destroy.md): primeiro os labs, depois `bootstrap` e `network`, por último o bucket de state (irreversível).

## Mais documentação

- [docs/runbook.md](docs/runbook.md): recuperação e problemas comuns.
- [docs/superpowers/specs/](docs/superpowers/specs/) e [plans/](docs/superpowers/plans/): design e plano de implementação, gerados com o fluxo brainstorm → plano → execução do plugin *superpowers* do Claude Code.

## Licença

[MIT](LICENSE).
