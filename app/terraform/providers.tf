terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.63.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

provider "aws" {
  alias  = "replica_region"
  region = "ap-southeast-2"
}

provider "aws" {
  alias  = "global"
  region = "us-east-1"
}
