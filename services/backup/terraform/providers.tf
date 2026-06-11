terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Identity comes from the environment (AWS_PROFILE=smc), never from code.
provider "aws" {
  region = var.region
}
