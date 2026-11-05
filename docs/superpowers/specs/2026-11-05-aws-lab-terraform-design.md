# aws-study-labs — Design

Data: 2026-11-05 · Autoria: decisões do autor + rascunho do Claude · Status: aguardando aprovação

Convenção: itens marcados **[Claude]** são decisões tomadas pelo Claude sem confirmação explícita do autor. Tudo o que não tem a marca foi dito ou aceito por ele.

## 1. Intenção

O autor quer um repositório pessoal para **aprender AWS na prática**, com infraestrutura que sobe e desce sob demanda, para não pagar por recursos esquecidos. O repo é Terraform.

O centro do projeto é uma **admin workstation**: uma EC2 na conta AWS, acessada por shell, de onde o autor roda AWS CLI, Terraform e kiro-cli para criar e validar recursos (roles, EC2, redes etc.). Os experimentos de estudo ("labs") são criados a partir dela.

- Repo GitHub: `<seu-usuario-github>/aws-study-labs` **[Claude]** (nome sugerido, ainda não criado).
- Pasta local: `<workspace>/aws-study-labs` (não é repositório git ainda).

## 2. Objetivos

1. Subir a base (state, workstation, rede) com poucos comandos, a partir do WSL do autor.
2. Rodar labs de dentro da workstation, clonando este mesmo repo.
3. Destruir um lab sem afetar a base nem outros labs.
4. Custo próximo de zero com tudo parado; nada caro fica ligado por esquecimento.
5. Poder criar recursos "na mão" para testes rápidos e limpá-los depois com segurança.
6. Servir de material de aprendizado: legível, comentado onde ajuda, com um README por lab.

## 3. Não-objetivos

- Produção, alta disponibilidade, multi-conta ou multi-ambiente.
- Módulos Terraform genéricos e reutilizáveis para terceiros. Estrutura plana por stack é preferível.
- Adotar OpenSpec ou outro framework de SDD. O fluxo é superpowers (design → plano → execução).
- Pipeline de CI/CD na primeira fase. **[Claude]** (`terraform fmt`/`validate` podem entrar depois.)

## 4. Anti-objetivos (seria falha mesmo funcionando)

- Credenciais ou o arquivo `.pem` dentro do repo ou da workstation.
- Um `destroy` de lab que derruba a workstation, a rede ou o bucket de state.
- A limpeza automática apagar algo que o autor queria manter.
- Recurso caro (NAT Gateway, RDS, EKS) ligado sem que o autor tenha decidido.

## 5. Restrições e fatos

- A conta AWS é **dedicada a estudo**. o autor confirmou que só tem coisa de estudo nela.
- Existem projetos anteriores (laboratórios de Terraform e Kubernetes). Antes da primeira limpeza automática, é preciso inventariar a conta e proteger ou descartar o que existir deles.
- Key pair já existente na AWS: `<seu-key-pair>` (arquivo local `<caminho-do-seu-key-pair>.pem`, permissão 400). O Terraform só usa o **nome** do key pair; o `.pem` serve só para SSH e nunca entra no repo.
- Comando de referência do autor para subir infra: `terraform apply -auto-approve -var="key_name=<seu-key-pair>"`. As stacks devem aceitar a variável `key_name`.
- Ferramentas locais verificadas: Terraform 1.11.1 (suporta lock nativo no S3 via `use_lockfile`), aws-cli 1.36.38, kiro-cli presente em `~/.local/bin`.
- Plugin `deploy-on-aws` já instalado (skills de diagrama/deploy e MCPs de preços e docs AWS).
- Commits sem trailer `Co-Authored-By` (regra global do autor).
- Região padrão: `us-east-1` **[Claude]** (já é a região do `~/.aws/config` do autor).
- Identidade usada no WSL (verificado com `aws sts get-caller-identity`): IAM user `admin`, conta `<ACCOUNT_ID>`, access keys em `~/.aws/credentials`. É a identidade que roda `state-backend/`, `bootstrap/`, `network/` e o nuke. A conta **não tem alias** (o aws-nuke exige um); criar o alias é parte do plano.

## 6. Estrutura do repo (decidido)

Um repo comum; cada pasta é uma stack Terraform independente, com state próprio.

```
aws-study-labs/
├── state-backend/   # bucket S3 de state. Criado uma vez, nunca destruído
├── bootstrap/       # workstation, role, permissions boundary, budget
├── network/         # VPC, subnets, IGW, security groups básicos (persistente)
├── labs/
│   ├── ec2-basico/  # exemplo; um state por lab
│   └── ...
├── docs/
└── .gitignore       # bloqueia *.pem, *.tfstate*, .terraform/, *.tfvars com segredos
```

### State

- Decidido pelo autor: **state em bucket S3**.
- **[Claude]** Lock nativo (`use_lockfile = true`), versionamento ligado, bloqueio de acesso público, criptografia padrão, uma chave por stack (ex.: `network/terraform.tfstate`, `labs/ec2-basico/terraform.tfstate`).
- `state-backend/` é o único caso de ovo-e-galinha: nasce com state local. **[Claude]** Depois de criado, o state do próprio `state-backend/` migra para o bucket (chave `state-backend/terraform.tfstate`). O bucket tem `prevent_destroy` e nome com sufixo do ID da conta (`aws-lab-tfstate-<account_id>`), descoberto por `aws_caller_identity`.

### Como os labs usam a base

- Os labs **não herdam** automaticamente; leem a `network/` explicitamente.
- **[Claude]** Início com `terraform_remote_state` (lê outputs `vpc_id`, `subnet_ids`). Migrar para data sources por tag ou SSM fica aberto se o acoplamento incomodar.
- **[Claude]** A `network/` nasce genérica: 1 VPC, 2 subnets públicas em AZs diferentes, Internet Gateway, route table, sem NAT Gateway. O NAT, quando necessário, é um lab próprio que sobe e desce.

## 7. Admin workstation (decidido)

- EC2 na conta do autor, com AWS CLI, Terraform e kiro-cli instalados (via user data ou AMI base). Instalação do kiro-cli na Linux da instância fica a cargo do builder.
- **[Claude]** Tipo `t4g.micro` ou `t3.micro`; o autor para a instância quando não usa. O builder deve escolher entre arm64 e x86_64 considerando que kiro-cli e Terraform têm builds para ambos, e comprovar isso.
- Sobe a partir do WSL do autor com `bootstrap/`.
- Acesso: SSH com `<seu-key-pair>` é aceito (o autor mencionou). **[Claude]** Recomendação: habilitar SSM Session Manager como caminho principal, mantendo SSH restrito ao IP do autor como alternativa, ou desligado.
- Credenciais: IAM role via instance profile; nenhuma access key guardada na máquina.
- Dentro dela, o autor clona este repo e roda `labs/*`.
- **[Claude]** Rede da workstation: subnet pública com IP público, sem NAT. SSM funciona pela internet pública (sem VPC endpoints, que cobram por hora).
- **[Claude]** SSH: desligado por padrão; variável opcional `ssh_cidrs` (lista de CIDRs) liga a porta 22. O IP residencial muda, então não se fixa um IP no código. `<seu-key-pair>` continua como `key_name`, para o SSH quando ligado.
- **[Claude]** Dados: o disco EBS persiste em stop/start. Sem Elastic IP (cobra parado); o IP público muda a cada start e o SSM não depende dele. Se a workstation for recriada, o disco se perde: tudo importante está no GitHub e a instalação é reproduzível por user data.
- **[Claude]** AWS CLI v2 na workstation (o WSL tem v1, aceitável lá).

## 8. Limites de segurança e custo

Camadas decididas como "começo" **[Claude]** (o autor perguntou como seriam e não rejeitou; precisam de confirmação final ao ler este documento):

1. **Permissions boundary** na role da workstation: ela só cria roles que carreguem a mesma boundary (sem escalada de privilégio).
2. **Condições IAM:** região restrita (`us-east-1`), tipos de instância permitidos limitados (`t3.*`, `t4g.*` e similares baratos), negação de serviços caros (NAT Gateway, EKS, RDS grande), liberáveis conscientemente.
3. A role da workstation **não pode alterar nem apagar a si mesma nem a boundary**.
4. **AWS Budgets** com alerta por e-mail (limite de US$10 por mês). Budget action com policy de negação é opcional.
5. Tags padrão (`default_tags`) em tudo: `project = aws-lab`. Recursos permanentes levam também `persist = true`.

Permissões da role da workstation **[Claude]**: começar com EC2, VPC, IAM (sob a boundary), S3, SSM, CloudWatch e leitura geral; leitura e escrita no bucket de state. Ampliar depois, editando o `bootstrap/` pelo WSL com a identidade `admin`. A lista de serviços caros negados só é levantada da mesma forma, por decisão consciente do autor.

Budget **[Claude]**: sobre o gasto total da conta (a conta é só de estudo); limite mensal de **US$10** (definido pelo autor); alertas em 50%, 80% e 100% do limite **[Claude]**; sem budget action no início. E-mail dos alertas: `<seu-email>` (definido pelo autor), passado como variável do `bootstrap/`.

Fase 2, fora do escopo inicial: parada automática por horário da workstation; exigir tag na criação via `aws:RequestTag`.

## 9. Limpeza com nuke (decidido em linhas gerais)

- Ferramenta: aws-nuke (fork mantido `ekristen/aws-nuke`; o original foi arquivado, confirmar antes de instalar) ou cloud-nuke. O builder escolhe após verificar o estado atual dos projetos.
- Padrão: **apagar tudo, menos o que tem `persist=true`**. Isso é seguro porque a conta é só de estudo.
- Protegidos por tag: workstation, rede, bucket de state, roles e boundary, budget, o usuário/role que roda o nuke.
- Fluxo obrigatório: dry-run → o autor lê a lista → `--no-dry-run`. Sem agendamento no começo.
- Executado com a identidade administrativa do autor, **não** pela role da workstation.
- Para recursos criados via Terraform, o caminho correto é `terraform destroy`; o nuke é para o que foi criado manualmente (evita drift nos states).
- **[Claude]** Recursos que não aceitam tag (itens de IAM, service-linked roles, VPC default, o próprio budget) são protegidos por filtros de tipo/nome no arquivo de configuração, além da tag. O key pair `<seu-key-pair>` é protegido por nome.
- **[Claude]** O inventário da conta (recursos do projetos anteriores) é um **portão obrigatório** antes do primeiro `--no-dry-run`, feito em conjunto: o Claude lista, o o autor decide o que fica.
- Pré-requisito: alias da conta configurado (exigido pelo aws-nuke) e inventário prévio dos recursos de projetos antigos.

## 10. Fluxo de uso

1. WSL: `state-backend/` → `network/` → `bootstrap/` (uma vez). **[Claude]** A `network/` vem antes porque a workstation precisa de subnet e security group; o `bootstrap/` lê a rede por `terraform_remote_state`.
2. O autor entra na workstation (SSM ou SSH).
3. Clona o repo, entra em `labs/<nome>`, `terraform init` + `apply`.
4. Estuda e valida com aws-cli/kiro-cli.
5. `terraform destroy` do lab. A base continua.
6. De vez em quando: dry-run do nuke para pegar o que ficou esquecido.

## 11. Em aberto (o autor ainda não definiu)

- Primeiros assuntos de estudo (ex.: IAM, EC2, VPC, S3). Define quais labs entram primeiro. O design acima não depende disso; a `network/` genérica serve de base.
- Confirmar o nome do repo e a região.
- Confirmar a política de SSH proposta (desligado por padrão, ligado por variável).

## 12. Deixado ao builder

- Estrutura interna de cada `.tf`, nomes de variáveis e outputs, e organização do `Makefile`/scripts auxiliares.
- Método de instalação das ferramentas na workstation (user data, AMI, script).
- Escolha arm64 vs x86_64 e tamanho da instância, dentro do orçamento.
- Texto exato das policies IAM, desde que respeitem a seção 8.
- Escolha final da ferramenta de nuke e do formato do arquivo de configuração.
- Convenção de README por lab e formato do `docs/`.
