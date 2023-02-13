# API
resource "aws_api_gateway_rest_api" "api_gateway_api_replica" {
  provider = aws.replica_region
  name     = "G2Team8"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Stage
resource "aws_api_gateway_stage" "api_gateway_stage_replica" {
  provider           = aws.replica_region
  deployment_id      = aws_api_gateway_deployment.api_gateway_deployment_replica.id
  rest_api_id        = aws_api_gateway_rest_api.api_gateway_api_replica.id
  stage_name         = "prod"
  cache_cluster_size = 0.5
  variables = {
    vpcLinkId = "${aws_api_gateway_vpc_link.vpc_link_nlb_replica.id}"
  }
}


# # Method settings
resource "aws_api_gateway_method_settings" "api_gateway_method_settings_replica" {
  provider    = aws.replica_region
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api_replica.id
  stage_name  = aws_api_gateway_stage.api_gateway_stage_replica.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
  }
}

# Deployment
resource "aws_api_gateway_deployment" "api_gateway_deployment_replica" {
  provider    = aws.replica_region
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api_replica.id

  triggers = {
    redeployment = filesha1("${path.module}/api_gateway_replica.tf")
  }

  lifecycle {
    create_before_destroy = true
  }
}

# VPC link integration to NLB 
resource "aws_api_gateway_vpc_link" "vpc_link_nlb_replica" {
  provider    = aws.replica_region
  name        = "vpc_link_nlb"
  description = "VPC link integration with NLB"
  target_arns = [module.nlb_replica.lb_arn]
}


resource "aws_api_gateway_resource" "api_root_replica" {
  provider    = aws.replica_region
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api_replica.id
  parent_id   = aws_api_gateway_rest_api.api_gateway_api_replica.root_resource_id
  path_part   = "{proxy+}"
}


resource "aws_api_gateway_method" "proxy_method_replica" {
  provider           = aws.replica_region
  rest_api_id        = aws_api_gateway_rest_api.api_gateway_api_replica.id
  resource_id        = aws_api_gateway_resource.api_root_replica.id
  http_method        = "ANY"
  authorization      = "NONE"
  request_parameters = { "method.request.path.proxy" = true }
}

resource "aws_api_gateway_integration" "proxy_vpc_link_integration_replica" {
  provider    = aws.replica_region
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api_replica.id
  resource_id = aws_api_gateway_resource.api_root_replica.id
  http_method = aws_api_gateway_method.proxy_method_replica.http_method

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
  cache_key_parameters = ["method.request.path.proxy"]

  type                    = "HTTP_PROXY"
  uri                     = "http://${module.nlb_replica.lb_dns_name}/{proxy}"
  integration_http_method = "ANY"
  passthrough_behavior    = "WHEN_NO_MATCH"

  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.vpc_link_nlb_replica.id
}

# Lamdba cognito login integration
resource "aws_api_gateway_resource" "login_resource_replica" {
  provider    = aws.replica_region
  path_part   = "login"
  parent_id   = aws_api_gateway_rest_api.api_gateway_api_replica.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api_replica.id
}

resource "aws_api_gateway_method" "cognito_login_replica" {
  provider      = aws.replica_region
  rest_api_id   = aws_api_gateway_rest_api.api_gateway_api_replica.id
  resource_id   = aws_api_gateway_resource.login_resource_replica.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cognito_login_integration_replica" {
  provider                = aws.replica_region
  rest_api_id             = aws_api_gateway_rest_api.api_gateway_api_replica.id
  resource_id             = aws_api_gateway_resource.login_resource_replica.id
  http_method             = aws_api_gateway_method.cognito_login_replica.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.cognito_login_function_replica.lambda_function_invoke_arn
}

resource "aws_api_gateway_method_response" "HTTP_OK_replica" {
  provider    = aws.replica_region
  rest_api_id = aws_api_gateway_rest_api.api_gateway_api_replica.id
  resource_id = aws_api_gateway_resource.login_resource_replica.id
  http_method = aws_api_gateway_method.cognito_login_replica.http_method
  status_code = "200"
}

resource "aws_api_gateway_model" "default_model_replica" {
  provider     = aws.replica_region
  rest_api_id  = aws_api_gateway_rest_api.api_gateway_api_replica.id
  name         = "Empty"
  content_type = "application/json"

  schema = <<EOF
{}
EOF
}

module "cors_replica" {
  providers = {
    aws = aws.replica_region
  }
  source            = "squidfunk/api-gateway-enable-cors/aws"
  version           = "0.3.3"
  allow_credentials = true

  api_id          = aws_api_gateway_rest_api.api_gateway_api_replica.id
  api_resource_id = aws_api_gateway_resource.api_root_replica.id
}

module "cognito_login_cors_replica" {
  providers = {
    aws = aws.replica_region
  }
  source  = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.api_gateway_api_replica.id
  api_resource_id = aws_api_gateway_resource.login_resource_replica.id
}
