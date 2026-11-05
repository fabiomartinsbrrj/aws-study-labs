terraform {
  backend "s3" {
    key          = "state-backend/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
