module "dynamo_endpoint_db" {
  source = "terraform-aws-modules/dynamodb-table/aws"

  name         = "${var.namespace}-endpoint_db"
  billing_mode = "PAY_PER_REQUEST"

  hash_key         = "name"
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attributes = [
    {
      name = "name"
      type = "S"
    }
  ]

  read_capacity  = 5
  write_capacity = 1
  stream_enabled = true
  autoscaling_read = {
    target_value = 50
    max_capacity = 30
  }

  server_side_encryption_enabled     = true
  server_side_encryption_kms_key_arn = aws_kms_key.default.arn

  replica_regions = [{
    region_name = "${var.replica_region}"
    kms_key_arn = "${aws_kms_key.replica.arn}"
  }]
}

data "aws_dynamodb_table" "dynamodb_replica" {
  provider = aws.replica_region
  name     = "${var.namespace}-endpoint_db"
}
