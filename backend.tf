terraform {
  backend "s3" {
    bucket       = "adarsh-tfstate-dynamobucket-20261029"
    key          = "terraform-project/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
