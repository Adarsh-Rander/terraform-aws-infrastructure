terraform {
  backend "s3" {
    bucket       = "adarsh-tfstate-dynamobucket"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
