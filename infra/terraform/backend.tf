terraform {
  backend "s3" {
    key          = "urbanmove/dev/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}
