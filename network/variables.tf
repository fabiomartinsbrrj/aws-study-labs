variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  description = "Bucket S3 de state (passado pelo Makefile)."
  type        = string
}
