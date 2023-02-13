resource "aws_ecr_repository" "g2team8_sevenrooms" {
  name                 = "sevenrooms_middleware"
  image_tag_mutability = "MUTABLE"
  encryption_configuration {
    encryption_type = "KMS"
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "g2team8_memberson" {
  name                 = "memberson_middleware"
  image_tag_mutability = "MUTABLE"
  encryption_configuration {
    encryption_type = "KMS"
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "g2team8_stripe" {
  name                 = "stripe_middleware"
  image_tag_mutability = "MUTABLE"
  encryption_configuration {
    encryption_type = "KMS"
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Multi region replication
data "aws_caller_identity" "current" {}

resource "aws_ecr_replication_configuration" "ecr_replication" {
  replication_configuration {
    rule {
      destination {
        region      = var.replica_region
        registry_id = data.aws_caller_identity.current.account_id
      }
    }
  }
}

data "aws_ecr_repository" "ecr_sevenrooms_replica" {
  provider = aws.replica_region
  name     = "sevenrooms_middleware"
}

data "aws_ecr_repository" "ecr_memberson_replica" {
  provider = aws.replica_region
  name     = "memberson_middleware"
}

data "aws_ecr_repository" "ecr_stripe_replica" {
  provider = aws.replica_region
  name     = "stripe_middleware"
}
