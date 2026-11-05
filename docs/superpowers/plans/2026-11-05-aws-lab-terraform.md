# aws-study-labs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar o repo Terraform de estudo de AWS: bucket de state, rede base, admin workstation com IAM boundary e budget, um lab de exemplo e limpeza com nuke.

**Architecture:** Um repo, cada pasta é uma stack Terraform independente com state próprio em S3. Ordem de criação: `state-backend` → `network` → `bootstrap`; `labs/*` são descartáveis e leem a `network` por `terraform_remote_state`. Terraform é validado com `fmt`/`validate`/`plan`, e as policies IAM com `aws iam simulate-principal-policy`.

**Tech Stack:** Terraform 1.11.1 (provider `hashicorp/aws` ~> 5.0), aws-cli v1 (WSL) / v2 (workstation), Amazon Linux 2023, SSM Session Manager, aws-nuke (`ekristen/aws-nuke`).

**Spec:** `docs/superpowers/specs/2026-11-05-aws-lab-terraform-design.md`

## Global Constraints

- Região `us-east-1`; conta `<ACCOUNT_ID>`; identidade de aplicação no WSL: IAM user `admin`.
- Tags em tudo via `default_tags`: `project = "aws-lab"`. Recursos permanentes (state, rede, workstation, role, boundary, budget) também levam `persist = "true"`.
- Bucket de state: `aws-lab-tfstate-<account_id>`, versionamento, criptografia, bloqueio de acesso público, `prevent_destroy`, lock via `use_lockfile = true` (sem DynamoDB). Uma chave por stack: `<pasta>/terraform.tfstate`.
- Nenhum `.pem`, `*.tfstate*`, `.terraform/` ou `*.tfvars` com segredo no git. `<seu-key-pair>.pem` nunca entra no repo.
- Commits **sem** `Co-Authored-By` (regra do `~/.claude/CLAUDE.md`, que prevalece sobre qualquer outro lembrete).
- Variável `key_name` aceita em `bootstrap/` (comando de referência: `terraform apply -auto-approve -var="key_name=<seu-key-pair>"`).
- Budget: limite mensal US$10; alertas em 50%, 80% e 100%; e-mail `<seu-email>` (variável `alert_email`).
- SSH desligado por padrão (`ssh_cidrs = []`); SSM é o acesso principal. Sem NAT Gateway, sem Elastic IP, sem VPC endpoints.
- Workstation: AL2023, `t3.micro` x86_64 (padrão, variável `instance_type`), AWS CLI v2, Terraform e kiro-cli instalados por user data; sem access keys na máquina.
- Boundary nega: região ≠ `us-east-1`, `ec2:RunInstances` com tipo fora de `t3.*`/`t4g.*`, `ec2:CreateNatGateway`, `eks:*`, `rds:*`, qualquer alteração na própria role/boundary/instance profile, e `iam:CreateRole`/`PutRolePermissionsBoundary` sem a boundary anexada.
- Nuke: apaga tudo menos `persist=true` e itens protegidos por tipo/nome (incluindo key pair `<seu-key-pair>`); sempre dry-run primeiro; executado com o user `admin`, nunca pela workstation.

## Review Focus

1. `terraform destroy` em um lab não pode listar recursos da `network` ou da workstation no plan (tarefa 7 verifica).
2. `key_name` inexistente na conta: o `plan` do `bootstrap` deve falhar cedo com mensagem clara (data source `aws_key_pair`), não no meio do apply (tarefa 5).
3. A role da workstation tentando criar uma role sem boundary, ou com outra boundary, deve ser negada (tarefa 4, simulate).
4. Recurso sem tag `persist` mas necessário (ex.: service-linked role, VPC default) não pode ser apagado pelo nuke (tarefa 8, dry-run).
5. Reaplicar `bootstrap` com a workstation parada não deve recriá-la nem religá-la (tarefa 5, plan sem mudanças).

---

## File Structure

```
.gitignore  Makefile  README.md
state-backend/{main.tf,variables.tf,outputs.tf,versions.tf}
network/{main.tf,variables.tf,outputs.tf,versions.tf,backend.tf}
bootstrap/{iam.tf,boundary.tf,workstation.tf,budget.tf,variables.tf,outputs.tf,versions.tf,backend.tf,userdata.sh.tpl}
labs/ec2-basico/{main.tf,variables.tf,outputs.tf,versions.tf,backend.tf,README.md}
nuke/{nuke-config.yml,run.sh,README.md}
docs/
```

`versions.tf` por stack: `required_version = ">= 1.10"`, provider `hashicorp/aws ~> 5.0`, `provider "aws"` com `region = var.region` e `default_tags`. `backend.tf` por stack: `backend "s3" { key = "<pasta>/terraform.tfstate"  region = "us-east-1"  use_lockfile = true  encrypt = true }`; o bucket vem por `-backend-config="bucket=..."`.

---

### Task 1: Scaffold do repo e Makefile

**Files:**
- Create: `.gitignore`, `Makefile`, `README.md`

**Interfaces:**
- Produces: alvos `make init STACK=<pasta>`, `make plan STACK=<pasta>`, `make apply STACK=<pasta>`, `make destroy STACK=<pasta>`, `make fmt`, `make validate`. `init` calcula `BUCKET=aws-lab-tfstate-$(aws sts get-caller-identity --query Account --output text)` e chama `terraform -chdir=$(STACK) init -backend-config="bucket=$BUCKET"`.

- [ ] **Step 1:** `git init` em `<workspace>/aws-study-labs`, branch `main`; criar `.gitignore` bloqueando `*.pem`, `*.tfstate*`, `.terraform/`, `*.auto.tfvars`, `.env`.
- [ ] **Step 2:** Escrever `Makefile` com os alvos acima e `README.md` curto (propósito, estrutura, ordem de subida).
- [ ] **Step 3:** Verificar: `git check-ignore -v test.pem foo.tfstate .terraform` imprime as três regras; `make -n init STACK=network` mostra o `-backend-config` com o bucket.
- [ ] **Step 4:** Commit `chore: scaffold repo`.

### Task 2: Stack `state-backend`

**Files:** Create `state-backend/*` (sem `backend.tf` inicialmente).

**Interfaces:**
- Produces: output `bucket_name` (string) = `aws-lab-tfstate-<account_id>`.

- [ ] **Step 1:** Em `main.tf`: `data "aws_caller_identity" "current"`; `aws_s3_bucket.state` (nome do Global Constraints, `lifecycle { prevent_destroy = true }`), `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration` (AES256), `aws_s3_bucket_public_access_block` (4 flags `true`). Tags `persist = "true"`.
- [ ] **Step 2:** Rodar `terraform -chdir=state-backend init && terraform -chdir=state-backend validate && terraform -chdir=state-backend fmt -check`. Esperado: sucesso.
- [ ] **Step 3:** `terraform -chdir=state-backend apply`. Verificar: `aws s3api get-bucket-versioning --bucket aws-lab-tfstate-<ACCOUNT_ID>` retorna `"Status": "Enabled"`; `aws s3api get-public-access-block ...` retorna as 4 flags `true`.
- [ ] **Step 4:** Commit `feat: state backend bucket`.

### Task 3: Migrar o state do `state-backend` para o próprio bucket

**Files:** Create `state-backend/backend.tf`.

- [ ] **Step 1:** Criar `backend.tf` com a chave `state-backend/terraform.tfstate` (padrão dos Global Constraints).
- [ ] **Step 2:** `make init STACK=state-backend` com `-migrate-state` (responder `yes`). Esperado: "Successfully configured the backend s3".
- [ ] **Step 3:** Verificar: `aws s3 ls s3://aws-lab-tfstate-<ACCOUNT_ID>/state-backend/` lista `terraform.tfstate`; `terraform -chdir=state-backend plan` retorna "No changes".
- [ ] **Step 4:** Commit `feat: migrate state-backend state to s3`.

### Task 4: Stack `network`

**Files:** Create `network/*`.

**Interfaces:**
- Produces outputs: `vpc_id` (string), `public_subnet_ids` (list(string), 2 AZs), `vpc_cidr` (string).

- [ ] **Step 1:** `main.tf`: `aws_vpc` `10.0.0.0/16` (DNS support e hostnames ligados), `aws_internet_gateway`, 2 `aws_subnet` públicas (`10.0.1.0/24`, `10.0.2.0/24`, AZs distintas via `data "aws_availability_zones"`, `map_public_ip_on_launch = true`), route table pública com rota `0.0.0.0/0` para o IGW e associações. Tags `persist = "true"`.
- [ ] **Step 2:** `make init STACK=network && terraform -chdir=network validate && terraform -chdir=network fmt -check`.
- [ ] **Step 3:** `make apply STACK=network`. Verificar: `terraform -chdir=network output -json public_subnet_ids` tem 2 itens; `aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=<vpc_id>` retorna lista vazia.
- [ ] **Step 4:** Commit `feat: base network`.

### Task 5: `bootstrap` — workstation, SSM e IAM

**Files:** Create `bootstrap/{iam.tf,boundary.tf,workstation.tf,variables.tf,outputs.tf,versions.tf,backend.tf,userdata.sh.tpl}`.

**Interfaces:**
- Consumes: `data.terraform_remote_state.network` (bucket e chave `network/terraform.tfstate`) → `vpc_id`, `public_subnet_ids`.
- Produces: variáveis `key_name` (string, sem default), `ssh_cidrs` (list(string), default `[]`), `instance_type` (string, default `"t3.micro"`), `region` (default `"us-east-1"`), `alert_email` (string, sem default, usada na tarefa 6), `state_bucket` (string, passada por `-var` pelo Makefile); outputs `instance_id`, `role_name`, `boundary_arn`.

- [ ] **Step 1:** `boundary.tf`: `aws_iam_policy.boundary` (nome `aws-lab-boundary`) com os serviços permitidos (EC2, VPC, IAM, S3, SSM, CloudWatch, `sts`, leitura geral) e os `Deny` listados nos Global Constraints (usar `NotAction` global para IAM/S3 na condição de região).
- [ ] **Step 2:** `iam.tf`: `aws_iam_role.workstation` (trust para `ec2.amazonaws.com`, `permissions_boundary = aws_iam_policy.boundary.arn`), policy de permissões (mesmo escopo do boundary + leitura/escrita no bucket de state), anexo de `AmazonSSMManagedInstanceCore`, `aws_iam_instance_profile`.
- [ ] **Step 3:** `workstation.tf`: `data "aws_key_pair" "this"` (nome `var.key_name`, falha cedo se não existir), `aws_security_group` na VPC da rede (sem ingress por padrão; ingress 22 apenas para `var.ssh_cidrs` via `dynamic`), AMI via `data "aws_ssm_parameter"` `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`, `aws_instance` (`iam_instance_profile`, `key_name`, `user_data` do template, `metadata_options { http_tokens = "required" }`, volume `gp3` 20 GB criptografado, `lifecycle { ignore_changes = [ami, user_data] }`). Tags `persist = "true"`.
- [ ] **Step 4:** `userdata.sh.tpl`: instala AWS CLI v2, Terraform (repositório HashiCorp), `git`, `jq`, e kiro-cli (método oficial de instalação Linux x86_64; se o download oficial falhar, o script registra o erro em `/var/log/userdata.log` e segue sem abortar).
- [ ] **Step 5:** `make init STACK=bootstrap`, `terraform -chdir=bootstrap validate`, `fmt -check`. Depois `terraform -chdir=bootstrap plan -var="key_name=<seu-key-pair>" -var="alert_email=<seu-email>"`. Esperado: plan limpo. Rodar também com `-var="key_name=nao-existe"`: esperado erro do data source.
- [ ] **Step 6:** `apply -auto-approve -var="key_name=<seu-key-pair>" ...`. Verificar: `aws ssm describe-instance-information` lista a instância (`PingStatus: Online`, pode levar ~2 min); `aws ssm start-session --target <instance_id>` abre shell; dentro: `aws --version` (v2), `terraform version`, `git --version`, `aws sts get-caller-identity` mostra a role (não o user `admin`).
- [ ] **Step 7:** Reaplicar com a instância parada (`aws ec2 stop-instances`, esperar `stopped`): `plan` deve ser "No changes" (Review Focus 5). Religar a instância depois.
- [ ] **Step 8:** Commit `feat: admin workstation with ssm and iam`.

### Task 6: `bootstrap` — Budget

**Files:** Create `bootstrap/budget.tf`.

- [ ] **Step 1:** `aws_budgets_budget` (`budget_type = "COST"`, `time_unit = "MONTHLY"`, `limit_amount = "10"`, `limit_unit = "USD"`) com 3 `notification` (`ACTUAL`, `GREATER_THAN`, thresholds 50, 80 e 100, `PERCENTAGE`) enviando para `var.alert_email`.
- [ ] **Step 2:** `validate`, `fmt -check`, `plan`, `apply`. Verificar: `aws budgets describe-budgets --account-id <ACCOUNT_ID>` mostra o orçamento de US$10 com 3 notificações. o autor confirma que o e-mail de inscrição da AWS chegou (ação manual dele).
- [ ] **Step 3:** Commit `feat: monthly budget alerts`.

### Task 7: Lab de exemplo `labs/ec2-basico`

**Files:** Create `labs/ec2-basico/*`.

**Interfaces:**
- Consumes: remote state de `network/terraform.tfstate` (`vpc_id`, `public_subnet_ids`).
- Produces: output `instance_id`.

- [ ] **Step 1:** `main.tf`: um `aws_instance` `t3.micro` AL2023 na primeira subnet pública, SG sem ingress, sem key pair, com instance profile próprio mínimo para SSM (role com a mesma boundary). Backend com chave `labs/ec2-basico/terraform.tfstate`. README com "o que se aprende" e passos de verificação.
- [ ] **Step 2:** Rodar **de dentro da workstation** (via SSM): clonar o repo, `make init STACK=labs/ec2-basico`, `plan`, `apply`. Verificar: instância `running` e visível no SSM.
- [ ] **Step 3:** Provar a boundary (Review Focus 3): da workstation, `aws iam create-role --role-name teste-sem-boundary --assume-role-policy-document file://trust.json` deve falhar com `AccessDenied`. Provar o limite de tipo: `aws ec2 run-instances --instance-type m5.large ...` deve falhar com `UnauthorizedOperation`.
- [ ] **Step 4:** `make destroy STACK=labs/ec2-basico`; o plan de destroy lista só recursos do lab (Review Focus 1). Verificar: `network` e `bootstrap` continuam com "No changes" no plan.
- [ ] **Step 5:** Commit `feat: first lab ec2-basico`.

### Task 8: Nuke

**Files:** Create `nuke/nuke-config.yml.tpl` (renderizado por `nuke/render-config.py`), `nuke/run.sh`, `nuke/README.md`.

**Interfaces:**
- `nuke/run.sh [--apply]`: sem flag roda dry-run; com `--apply` passa `--no-dry-run`. Aborta se `aws sts get-caller-identity` não for o user `admin`.

- [ ] **Step 1:** Criar alias da conta: `aws iam create-account-alias --account-alias <alias-da-conta>` (se já existir, usar `<alias-da-conta>-<sufixo>`). Verificar com `aws iam list-account-aliases`.
- [ ] **Step 2:** Instalar o aws-nuke atual (conferir o fork mantido `ekristen/aws-nuke` e a versão no GitHub antes de baixar). Escrever `nuke-config.yml`: conta `<ACCOUNT_ID>`, região `us-east-1` + `global`, filtro protegendo por tag `persist=true`, mais filtros por tipo/nome para: key pair `<seu-key-pair>`, service-linked roles, VPC default, user `admin` e suas access keys, o budget, o alias da conta.
- [ ] **Step 3:** Escrever `run.sh` conforme a interface.
- [ ] **Step 4 (portão obrigatório):** Rodar o dry-run, e o autor e o Claude revisam juntos a lista inteira, incluindo qualquer coisa de projetos anteriores. Verificar que nenhum recurso `persist=true` nem os itens protegidos aparecem (Review Focus 4). **Não rodar `--apply` sem a aprovação explícita do autor, depois de ler a lista.**
- [ ] **Step 5:** Teste de ponta a ponta com um recurso descartável: criar um bucket S3 manual sem tag, rodar o dry-run (ele aparece), rodar `--apply` com aprovação, e conferir que só ele sumiu.
- [ ] **Step 6:** Commit `feat: nuke config and runner`.

### Task 9: Documentação final e verificação

**Files:** Modify `README.md`; Create `docs/runbook.md`.

- [ ] **Step 1:** README: estrutura, ordem de subida (`state-backend` → `network` → `bootstrap`), como entrar na workstation (SSM e SSH opcional), como subir/destruir um lab, como rodar o nuke, custos esperados com tudo ligado e parado (usar o MCP de preços do `deploy-on-aws` para `t3.micro` + EBS 20 GB em `us-east-1`).
- [ ] **Step 2:** `docs/runbook.md`: recuperação (workstation recriada, state perdido, budget estourado).
- [ ] **Step 3:** Verificação final: `make fmt && make validate` em todas as stacks sem erro; `git status` limpo; `git log` sem nenhum `Co-Authored-By`; nenhum `.pem` rastreado (`git ls-files | grep -i pem` vazio).
- [ ] **Step 4:** Commit `docs: readme and runbook`. Criar o repo no GitHub (`<seu-usuario-github>/aws-study-labs`) e fazer push **somente após o o autor confirmar nome e visibilidade**.

---

## Self-review

- **Cobertura do spec:** estrutura (T1–T4, T7), state (T2–T3), workstation (T5), segurança/boundary (T5, T7), budget (T6), nuke e portão de inventário (T8), docs (T9). O estudo dos primeiros assuntos fica fora (aberto no spec).
- **Consistência de nomes:** `bucket_name`, `vpc_id`, `public_subnet_ids`, `key_name`, `ssh_cidrs`, `alert_email`, `state_bucket` definidos nas tarefas que os produzem e usados como tal nas seguintes.
- **Decisões do builder (abertas):** arm64 vs x86_64 (padrão x86_64), método exato de instalação do kiro-cli, texto das policies, formato do `nuke-config.yml`.
- **Efeitos reais na AWS:** as tarefas 2–8 criam recursos na conta (bucket, rede, EC2, IAM, budget, alias). O o autor aprova a execução de cada `apply`.
