data "aws_availability_zones" "available" {}

// Create VPC
module "vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  name            = "${var.namespace}-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  enable_dns_hostnames   = true
  enable_dns_support     = true
}

// Cloud map internal DNS
resource "aws_service_discovery_private_dns_namespace" "g2team8" {
  name = "services.g2team8"
  vpc  = module.vpc.vpc_id
}

// Search for secrets manager in vpc endpoint service
data "aws_vpc_endpoint_service" "secrets_manager" {
  service = "secretsmanager"
}

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnets
  service_name        = data.aws_vpc_endpoint_service.secrets_manager.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.ssm_private.id]
  private_dns_enabled = true
}

// Search for dynamodb in vpc endpoint service
data "aws_vpc_endpoint_service" "dynamodb" {
  service = "dynamodb"
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = module.vpc.vpc_id
  service_name      = data.aws_vpc_endpoint_service.dynamodb.service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}

// Security Group for Secret Manager VPC Endpoint
resource "aws_security_group" "ssm_private" {
  name        = "${var.namespace}-ssm_private"
  description = "Allow SSH and ALB inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTPS to VPC Endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster_entry.id, aws_security_group.token_rotator_sg.id, aws_security_group.cognito_login_sg.id]
  }

  egress {
    description = "All traffic out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.namespace}-ssm_private"
  }
}

// LB to Cluster
resource "aws_security_group" "cluster_entry" {
  name        = "${var.namespace}-cluster_entry"
  description = "Allow ALB inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTP from LB"
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "Container Port from LB"
    protocol        = "tcp"
    from_port       = 8080
    to_port         = 8080
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "All traffic out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.namespace}-cluster_entry"
  }
}

// NLB to ALB
resource "aws_security_group" "alb_sg" {
  name        = "${var.namespace}-alb_sg"
  description = "Allow all inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP Access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS Access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All traffic out"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.namespace}-alb_sg"
  }

}

// All traffic to VPC link NLB
resource "aws_security_group" "vpclink_nlb_sg" {
  name        = "${var.namespace}-vpclink_nlb_sg"
  description = "Allow all inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP Access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS Access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All traffic out"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.namespace}-vpclink_nlb_sg"
  }

}

# Lambda token rotator SG
resource "aws_security_group" "token_rotator_sg" {
  name        = "${var.namespace}-token_rotator_sg"
  description = "Disbale inbound traffic"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "All traffic out"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.namespace}-token_rotator_sg"
  }
}

# Lambda failover SG
resource "aws_security_group" "failover_sg" {
  name        = "${var.namespace}-failover_sg"
  description = "Disable inbound traffic"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "All traffic out"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.namespace}-failover_sg"
  }
}

# SQS VPC link
data "aws_vpc_endpoint_service" "sqs" {
  service = "sqs"
}

// Security Group for SQS VPC Endpoint
resource "aws_security_group" "sqs_private" {
  name        = "${var.namespace}-sqs_private"
  description = "Inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTPS to VPC Endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster_entry.id, aws_security_group.token_rotator_sg.id, aws_security_group.failover_sg.id]
  }

  egress {
    description = "All traffic out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.namespace}-sqs_private"
  }
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnets
  service_name        = data.aws_vpc_endpoint_service.sqs.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.sqs_private.id]
  private_dns_enabled = true
}

# Lambda cognito login
resource "aws_security_group" "cognito_login_sg" {
  name        = "${var.namespace}-cognito_login_sg"
  description = "Allow inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP Access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All traffic out"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.namespace}-cognito_login_sg"
  }
}
