terraform {
  backend "s3" {
    bucket       = "own-uc-1"
    key          = "terraform.tfstate"
    region       = "us-west-1"
    
  }
}