# Uso: make <alvo> STACK=<pasta> [ARGS="-var=..."]
# Ex.:  make plan STACK=network
#       make apply STACK=bootstrap   (key_name e alert_email vem de bootstrap/terraform.tfvars)

SHELL := /bin/bash
STACK ?=
ARGS  ?=
ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
BUCKET     = aws-lab-tfstate-$(ACCOUNT_ID)
TF         = TF_VAR_state_bucket=$(BUCKET) terraform -chdir=$(STACK)

.PHONY: bootstrap-state init plan apply destroy fmt validate check-stack

check-stack:
	@test -n "$(STACK)" || { echo "Informe STACK=<pasta>"; exit 1; }
	@test -d "$(STACK)" || { echo "Stack '$(STACK)' nao existe"; exit 1; }

# Primeiro passo de uma conta nova: cria o bucket de state e migra o state para ele.
bootstrap-state:
	./scripts/bootstrap-state.sh

init: check-stack
	$(TF) init -backend-config="bucket=$(BUCKET)" $(INIT_ARGS)

plan: check-stack
	$(TF) plan $(ARGS)

apply: check-stack
	$(TF) apply $(ARGS)

destroy: check-stack
	$(TF) destroy $(ARGS)

fmt:
	terraform fmt -recursive

validate:
	@for d in state-backend network bootstrap labs/*; do \
	  if [ -d "$$d" ]; then echo "== $$d"; terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d validate || exit 1; fi; \
	done
