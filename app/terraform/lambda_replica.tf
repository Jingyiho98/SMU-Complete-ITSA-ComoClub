module "cognito_login_function_replica" {
  providers = {
    aws = aws.replica_region
  }
  source = "terraform-aws-modules/lambda/aws"

  function_name = "cognito_login_function"
  description   = "Get or create cognito user using Memberson Login credentials"
  handler       = "app.lambda_handler"
  runtime       = "python3.9"

  source_path = [
    {
      path             = "${path.module}/../lambda/memberson-login_replica",
      pip_requirements = true
    }
  ]
  vpc_subnet_ids         = module.vpc_replica.private_subnets
  vpc_security_group_ids = [aws_security_group.cognito_login_sg_replica.id]

  attach_network_policy = true

  create_role = false

  lambda_role = aws_iam_role.lambda_cognito_role.arn

  publish = true

  environment_variables = {
    "MEMBERSON_CREDENTIALS_ARN" = "${data.aws_secretsmanager_secret.memberson_credentials_replica.arn}",
    "MEMBERSON_TOKEN_ARN"       = "${data.aws_secretsmanager_secret.memberson_token_replica.arn}",
  }
}

resource "aws_lambda_permission" "allow_api_gateway_trigger_replica" {
  provider      = aws.replica_region
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.cognito_login_function_replica.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api_gateway_api_replica.execution_arn}/*/*/*"
}
