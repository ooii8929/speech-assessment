provider "aws" {
  region = "ap-northeast-1"
  profile = "alvin"
}

terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.7.0"
        }
    }
    required_version = ">=1.4.5"
}