#!/bin/bash
# Instala as ferramentas da admin workstation (Amazon Linux 2023). Log em /var/log/userdata.log
exec > >(tee -a /var/log/userdata.log) 2>&1
set -x

dnf install -y git jq unzip make dnf-plugins-core

# AWS CLI v2 (o AL2023 ja traz; instala so se faltar)
command -v aws >/dev/null || dnf install -y awscli

# Terraform (repositorio oficial HashiCorp)
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
dnf install -y terraform || echo "ERRO: terraform nao instalou"

# kiro-cli (instalador oficial). Se falhar, registra e segue.
sudo -u ec2-user bash -c 'curl -fsSL https://cli.kiro.dev/install -o /tmp/kiro-install.sh && bash /tmp/kiro-install.sh' \
  || echo "ERRO: kiro-cli nao instalou"
