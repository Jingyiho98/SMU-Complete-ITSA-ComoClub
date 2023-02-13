resource "aws_kms_key" "default" {
  description             = "Default Key"
  deletion_window_in_days = 7
}

resource "aws_kms_key" "replica" {
  provider                = aws.replica_region
  description             = "Replica Key"
  deletion_window_in_days = 7
}

resource "aws_secretsmanager_secret" "memberson_credentials" {
  name       = "MEMBERSON_CREDENTIALS"
  kms_key_id = aws_kms_key.default.key_id

  replica {
    kms_key_id = aws_kms_key.replica.key_id
    region     = var.replica_region
  }
}

resource "aws_secretsmanager_secret_version" "memberson_credentials" {
  secret_id     = aws_secretsmanager_secret.memberson_credentials.id
  secret_string = jsonencode(var.memberson_credentials)
}

resource "aws_secretsmanager_secret" "sevenrooms_credentials" {
  name       = "SEVENROOMS_CREDENTIALS"
  kms_key_id = aws_kms_key.default.key_id

  replica {
    kms_key_id = aws_kms_key.replica.key_id
    region     = var.replica_region
  }
}

resource "aws_secretsmanager_secret_version" "sevenrooms_credentials" {
  secret_id     = aws_secretsmanager_secret.sevenrooms_credentials.id
  secret_string = jsonencode(var.sevenrooms_credentials)
}

resource "aws_secretsmanager_secret" "sevenrooms_token" {
  name       = "SEVENROOMS_TOKEN"
  kms_key_id = aws_kms_key.default.key_id

  replica {
    kms_key_id = aws_kms_key.replica.key_id
    region     = var.replica_region
  }
}

resource "aws_secretsmanager_secret_version" "sevenrooms_token" {
  secret_id     = aws_secretsmanager_secret.sevenrooms_token.id
  secret_string = "placeholder"

  lifecycle {
    ignore_changes = [secret_string, version_stages]
  }
}

resource "aws_secretsmanager_secret" "memberson_token" {
  name       = "MEMBERSON_TOKEN"
  kms_key_id = aws_kms_key.default.key_id

  replica {
    kms_key_id = aws_kms_key.replica.key_id
    region     = var.replica_region
  }
}

resource "aws_secretsmanager_secret_version" "memberson_token" {
  secret_id     = aws_secretsmanager_secret.memberson_token.id
  secret_string = "placeholder"

  lifecycle {
    ignore_changes = [secret_string, version_stages]
  }
}

data "aws_secretsmanager_secret" "memberson_credentials_replica" {
  provider = aws.replica_region
  name     = aws_secretsmanager_secret.memberson_credentials.name
}
data "aws_secretsmanager_secret" "sevenrooms_credentials_replica" {
  provider = aws.replica_region
  name     = aws_secretsmanager_secret.sevenrooms_credentials.name
}
data "aws_secretsmanager_secret" "memberson_token_replica" {
  provider = aws.replica_region
  name     = aws_secretsmanager_secret.memberson_token.name
}
data "aws_secretsmanager_secret" "sevenrooms_token_replica" {
  provider = aws.replica_region
  name     = aws_secretsmanager_secret.sevenrooms_token.name
}
