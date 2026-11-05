terraform {
  backend "s3" {
    key          = "labs/ec2-basico/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
