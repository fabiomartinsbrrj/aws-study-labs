variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  description = "Bucket S3 de state (passado pelo Makefile)."
  type        = string
}

variable "key_name" {
  description = "Nome do key pair existente na AWS (ex.: meu-key-pair). Nao e o arquivo .pem."
  type        = string
}

variable "ssh_cidrs" {
  description = "CIDRs com acesso SSH (porta 22). Vazio = SSH desligado; acesso so por SSM."
  type        = list(string)
  default     = []
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "alert_email" {
  description = "E-mail que recebe os alertas do Budget."
  type        = string
}

variable "monthly_budget_usd" {
  type    = number
  default = 10
}
