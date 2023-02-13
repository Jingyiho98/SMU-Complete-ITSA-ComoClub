resource "aws_iam_role" "task_role" {
  name = "ECS_TASK"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks.json
}

resource "aws_iam_role" "execution_role" {
  name = "ECS_EXECUTION"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks.json
}

data "aws_iam_policy_document" "ecs_tasks" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "ecs_cluster" {
  name   = "g2team8-cluster-policy"
  policy = data.aws_iam_policy_document.ecs_cluster.json
}

data "aws_iam_policy_document" "ecs_cluster" {
  statement {
    sid    = "DeployService"
    effect = "Allow"

    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "RegisterTaskDefinition"
    effect = "Allow"

    actions = [
      "ecs:RegisterTaskDefinition"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PassRolesInTaskDefinition"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      aws_iam_role.execution_role.arn,
      aws_iam_role.task_role.arn
    ]
  }
}

resource "aws_iam_role_policy" "task" {
  name = "G2TEAM8_TASK_ROLE"
  role = aws_iam_role.task_role.id

  policy = data.aws_iam_policy_document.execution.json
}

resource "aws_iam_role_policy" "execution" {
  name = "G2TEAM8_EXECUTION_ROLE"
  role = aws_iam_role.execution_role.id

  policy = data.aws_iam_policy_document.execution.json
}

data "aws_iam_policy_document" "execution" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeTags",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:UpdateContainerInstancesState",
      "ecs:Submit*",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      aws_kms_key.default.arn,
      aws_kms_key.replica.arn,
      aws_secretsmanager_secret.sevenrooms_token.arn,
      aws_secretsmanager_secret.memberson_token.arn,
      aws_secretsmanager_secret.memberson_credentials.arn,
      data.aws_secretsmanager_secret.memberson_credentials_replica.arn,
      data.aws_secretsmanager_secret.memberson_token_replica.arn,
      data.aws_secretsmanager_secret.sevenrooms_token_replica.arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
    ]

    resources = [
      module.dynamo_endpoint_db.dynamodb_table_arn,
      data.aws_dynamodb_table.dynamodb_replica.arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
      "sqs:SendMessage",
      "kms:GenerateDataKey"
    ]

    resources = [
      aws_sqs_queue.failover_queue.arn,
      aws_kms_key.default.arn,
      aws_sqs_queue.failover_queue_replica.arn,
      aws_kms_key.replica.arn
    ]
  }
}


# Token rotator roles
resource "aws_iam_role" "lambda_token_rotator_role" {
  name = "LAMBDA_TOKEN_ROTATOR_ROLE"

  assume_role_policy = data.aws_iam_policy_document.lambda_token_rotator_assume_role.json
}
data "aws_iam_policy_document" "lambda_token_rotator_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda_token_rotator_policy" {
  name = "G2TEAM8_TOKEN_ROTATOR_ROLE"
  role = aws_iam_role.lambda_token_rotator_role.id

  policy = data.aws_iam_policy_document.lambda_token_rotator_policy_document.json
}
data "aws_iam_policy_document" "lambda_token_rotator_policy_document" {
  # Decrypt and read SSM secrets
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_kms_key.default.arn,
      aws_secretsmanager_secret.sevenrooms_credentials.arn,
      aws_secretsmanager_secret.memberson_credentials.arn,
      aws_kms_key.replica.arn,
      data.aws_secretsmanager_secret.memberson_credentials_replica.arn,
      data.aws_secretsmanager_secret.sevenrooms_credentials_replica.arn
    ]
  }

  # Read from dynamoDB
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
    ]

    resources = [
      module.dynamo_endpoint_db.dynamodb_table_arn,
      data.aws_dynamodb_table.dynamodb_replica.arn
    ]
  }

  # Cloudwatch log group
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "*"
    ]
  }

  # VPC network permissions

  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]
    resources = [
      "*"
    ]
  }

  # Update token
  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "secretsmanager:PutSecretValue",
    ]
    resources = [
      aws_kms_key.default.arn,
      aws_secretsmanager_secret.sevenrooms_token.arn,
      aws_secretsmanager_secret.memberson_token.arn,
      aws_kms_key.replica.arn,
      data.aws_secretsmanager_secret.memberson_token_replica.arn,
      data.aws_secretsmanager_secret.sevenrooms_token_replica.arn
    ]
  }
}

# Failover lambda function
resource "aws_iam_role" "failover_lambda_role" {
  name = "LAMBDA_FAILOVER_ROLE"

  assume_role_policy = data.aws_iam_policy_document.lambda_failover_assume_role.json
}
data "aws_iam_policy_document" "lambda_failover_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda_failover_policy" {
  name = "G2TEAM8_FAILOVER_QUEUE_ROLE"
  role = aws_iam_role.failover_lambda_role.id

  policy = data.aws_iam_policy_document.lambda_failover_policy_document.json
}

data "aws_iam_policy_document" "lambda_failover_policy_document" {
  # Decrypt and read SQS messages
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [
      aws_kms_key.default.arn,
      aws_sqs_queue.failover_queue.arn,
      aws_kms_key.replica.arn,
      aws_sqs_queue.failover_queue_replica.arn
    ]
  }

  # Cloudwatch log group
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "*"
    ]
  }

  # VPC network permissions
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage"
    ]

    resources = [
      aws_sqs_queue.failover_queue.arn,
      aws_sqs_queue.failover_queue_replica.arn
    ]
  }
}


# Lambda cognito login
resource "aws_iam_role" "lambda_cognito_role" {
  name = "LAMBDA_COGNITO_ROLE"

  assume_role_policy = data.aws_iam_policy_document.lambda_cognito_assume_role.json
}
data "aws_iam_policy_document" "lambda_cognito_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda_cognito_policy" {
  name = "G2TEAM8_COGNITO_LOGIN_ROLE"
  role = aws_iam_role.lambda_cognito_role.id

  policy = data.aws_iam_policy_document.lambda_cognito_policy_document.json
}

data "aws_iam_policy_document" "lambda_cognito_policy_document" {
  # Decrypt and read SSM
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_kms_key.default.arn,
      aws_secretsmanager_secret.memberson_credentials.arn,
      aws_secretsmanager_secret.memberson_token.arn,
      aws_kms_key.replica.arn,
      data.aws_secretsmanager_secret.memberson_credentials_replica.arn,
      data.aws_secretsmanager_secret.memberson_token_replica.arn
    ]
  }

  # Cloudwatch log group
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "*"
    ]
  }

  # VPC network permissions
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]
    resources = [
      "*"
    ]
  }

  # Read from dynamoDB
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
    ]

    resources = [
      module.dynamo_endpoint_db.dynamodb_table_arn,
      data.aws_dynamodb_table.dynamodb_replica.arn
    ]
  }

  # Cognito admin
  statement {
    effect = "Allow"

    actions = [
      "cognito-idp:AdminInitiateAuth",
      "cognito-idp:AdminCreateUser",
      "cognito-idp:AdminSetUserPassword"
    ]

    resources = [
      "${tolist(data.aws_cognito_user_pools.cognito.arns)[0]}"
    ]
  }
}
