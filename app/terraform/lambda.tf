
module "sevenrooms_token_rotator" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "sevenrooms_token_rotator"
  description   = "Rotates token for SevenRooms"
  handler       = "app.lambda_handler"
  runtime       = "python3.9"

  source_path = [
    {
      path             = "${path.module}/../lambda/7rooms-token",
      pip_requirements = true
    }
  ]
  vpc_subnet_ids         = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.token_rotator_sg.id]

  attach_network_policy = true

  create_role = false

  lambda_role = aws_iam_role.lambda_token_rotator_role.arn
  environment_variables = {
    "SEVENROOMS_CREDENTIALS_ARN" = "${aws_secretsmanager_secret.sevenrooms_credentials.arn}",
    "SEVENROOMS_TOKEN_ARN"       = "${aws_secretsmanager_secret.sevenrooms_token.arn}",
  }

  publish = true
  allowed_triggers = {
    SchedulerRule = {
      principal  = "events.amazonaws.com"
      source_arn = "${aws_cloudwatch_event_rule.token_rotator_scheduler.arn}"
    }
  }
}

module "memberson_token_rotator" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "memberson_token_rotator"
  description   = "Rotates token for Memberson"
  handler       = "app.lambda_handler"
  runtime       = "python3.9"

  source_path = [
    {
      path             = "${path.module}/../lambda/memberson-token",
      pip_requirements = true
    }
  ]
  vpc_subnet_ids         = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.token_rotator_sg.id]

  attach_network_policy = true

  create_role = false

  lambda_role = aws_iam_role.lambda_token_rotator_role.arn
  environment_variables = {
    "MEMBERSON_CREDENTIALS_ARN" = "${aws_secretsmanager_secret.memberson_credentials.arn}",
    "MEMBERSON_TOKEN_ARN"       = "${aws_secretsmanager_secret.memberson_token.arn}",
  }

  publish = true
  allowed_triggers = {
    SchedulerRule = {
      principal  = "events.amazonaws.com"
      source_arn = "${aws_cloudwatch_event_rule.token_rotator_scheduler.arn}"
    }
  }
}

resource "aws_cloudwatch_event_rule" "token_rotator_scheduler" {
  name                = "token_6_hour_rotation"
  description         = "Fires every 6 hours"
  schedule_expression = "rate(6 hours)"
}

resource "aws_cloudwatch_event_target" "rotate_sevenrooms_token" {
  rule = aws_cloudwatch_event_rule.token_rotator_scheduler.name
  arn  = module.sevenrooms_token_rotator.lambda_function_arn
}

resource "aws_cloudwatch_event_target" "rotate_memberson_token" {
  rule = aws_cloudwatch_event_rule.token_rotator_scheduler.name
  arn  = module.memberson_token_rotator.lambda_function_arn
}


module "failover_queue_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "failover_queue_function"
  description   = "Reads from SQS queue and retries previously failed API request."
  handler       = "app.lambda_handler"
  runtime       = "python3.9"

  source_path = [
    {
      path             = "${path.module}/../lambda/failover-queue",
      pip_requirements = true
    }
  ]
  vpc_subnet_ids         = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.failover_sg.id]

  attach_network_policy = true

  create_role = false

  lambda_role = aws_iam_role.failover_lambda_role.arn

  publish = true

  environment_variables = {
    "NLB_URL" = "${module.nlb.lb_dns_name}",
  }
}

resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.failover_queue.arn
  function_name    = module.failover_queue_function.lambda_function_arn
}

module "cognito_login_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "cognito_login_function"
  description   = "Get or create cognito user using Memberson Login credentials"
  handler       = "app.lambda_handler"
  runtime       = "python3.9"

  source_path = [
    {
      path             = "${path.module}/../lambda/memberson-login",
      pip_requirements = true
    }
  ]
  vpc_subnet_ids         = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.cognito_login_sg.id]

  attach_network_policy = true

  create_role = false

  lambda_role = aws_iam_role.lambda_cognito_role.arn

  publish = true

  environment_variables = {
    "MEMBERSON_CREDENTIALS_ARN" = "${aws_secretsmanager_secret.memberson_credentials.arn}",
    "MEMBERSON_TOKEN_ARN"       = "${aws_secretsmanager_secret.memberson_token.arn}",
    "USERPOOL"                  = "${var.cognito_user_pool_id}"
    "CLIENTID"                  = "${var.cognito_clientid}"
  }
}


resource "aws_lambda_permission" "allow_api_gateway_trigger" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.cognito_login_function.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api_gateway_api.execution_arn}/*/*/*"
}
