variable "namespace" {
  default = "g2team8"
}

variable "app_access_port" {
  default = "80"
}

variable "aws_region" {
  default = "ap-southeast-1"
}

variable "domain" {
  default = "itsag2t8.com"
}

variable "api_domain" {
  default = "api.itsag2t8.com"
}

variable "auth_domain" {
  default = "auth.itsag2t8.com"
}

variable "aus_api_domain" {
  default = "apiaus.itsag2t8.com"
}

variable "memberson_credentials" {
  type = map(string)
}

variable "sevenrooms_credentials" {
  type = map(string)
}

variable "serverless_acm_arn" {
  type = string
}

variable "aws_keys" {
  type = map(string)
}

variable "stripe_api_key" {
  type = string
}

variable "cognito_user_pool_name" {
  type = string
}

variable "cognito_user_pool_id" {
  type = string
}

variable "cognito_clientid" {
  type = string
}

variable "replica_region" {
  default = "ap-southeast-2"
}
