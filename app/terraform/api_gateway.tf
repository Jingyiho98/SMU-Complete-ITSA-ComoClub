# API
resource "aws_api_gateway_rest_api" "api_gateway_api" {
  name = "G2Team8"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Stage
resource "aws_api_gateway_stage" "api_gateway_stage" {
  deployment_id      = aws_api_gateway_deployment.api_gateway_deployment.id
  rest_api_id        = aws_api_gateway_rest_api.api_gateway_api.id
  stage_name         = "prod"
  cache_cluster_size = 0.5
  variables = {
    vpcLinkId = "${aws_api_gateway_vpc_link.vpc_link_nlb.id}"
  }
}


# # Method settings
resource "aws_api_gateway_method_settings" "api_gateway_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api.id
  stage_name  = aws_api_gateway_stage.api_gateway_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
  }
}

# Deployment
resource "aws_api_gateway_deployment" "api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api.id

  triggers = {
    redeployment = filesha1("${path.module}/api_gateway.tf")
  }

  lifecycle {
    create_before_destroy = true
  }
}

# VPC link integration to NLB 
resource "aws_api_gateway_vpc_link" "vpc_link_nlb" {
  name        = "vpc_link_nlb"
  description = "VPC link integration with NLB"
  target_arns = [module.nlb.lb_arn]
}


resource "aws_api_gateway_resource" "api_root" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api.id
  parent_id   = aws_api_gateway_rest_api.api_gateway_api.root_resource_id
  path_part   = "{proxy+}"
}


resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id        = aws_api_gateway_rest_api.api_gateway_api.id
  resource_id        = aws_api_gateway_resource.api_root.id
  http_method        = "ANY"
  authorization      = "COGNITO_USER_POOLS"
  authorizer_id      = aws_api_gateway_authorizer.cognito.id
  request_parameters = { "method.request.path.proxy" = true }
}

resource "aws_api_gateway_integration" "proxy_vpc_link_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api.id
  resource_id = aws_api_gateway_resource.api_root.id
  http_method = aws_api_gateway_method.proxy_method.http_method

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
  cache_key_parameters = ["method.request.path.proxy"]

  type                    = "HTTP_PROXY"
  uri                     = "http://${module.nlb.lb_dns_name}/{proxy}"
  integration_http_method = "ANY"
  passthrough_behavior    = "WHEN_NO_MATCH"

  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.vpc_link_nlb.id
}

# Lamdba cognito login integration
resource "aws_api_gateway_resource" "login_resource" {
  path_part   = "login"
  parent_id   = aws_api_gateway_rest_api.api_gateway_api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api.id
}

resource "aws_api_gateway_method" "cognito_login" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway_api.id
  resource_id   = aws_api_gateway_resource.login_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cognito_login_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway_api.id
  resource_id             = aws_api_gateway_resource.login_resource.id
  http_method             = aws_api_gateway_method.cognito_login.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.cognito_login_function.lambda_function_invoke_arn
}

resource "aws_api_gateway_method_response" "HTTP_OK" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api.id
  resource_id = aws_api_gateway_resource.login_resource.id
  http_method = aws_api_gateway_method.cognito_login.http_method
  status_code = "200"
}

# Cognito integration
data "aws_cognito_user_pools" "cognito" {
  name = var.cognito_user_pool_name
}

resource "aws_api_gateway_authorizer" "cognito" {
  name          = "cognito_authorizer"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.api_gateway_api.id
  provider_arns = data.aws_cognito_user_pools.cognito.arns
}

resource "aws_api_gateway_model" "default_model" {
  rest_api_id  = aws_api_gateway_rest_api.api_gateway_api.id
  name         = "Empty"
  content_type = "application/json"

  schema = <<EOF
{}
EOF
}

module "cors" {
  source            = "squidfunk/api-gateway-enable-cors/aws"
  version           = "0.3.3"
  allow_credentials = true

  api_id          = aws_api_gateway_rest_api.api_gateway_api.id
  api_resource_id = aws_api_gateway_resource.api_root.id
}

module "cognito_login_cors" {
  source  = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.api_gateway_api.id
  api_resource_id = aws_api_gateway_resource.login_resource.id
}
