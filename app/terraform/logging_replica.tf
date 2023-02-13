resource "aws_cloudwatch_log_group" "g2team8_replica" {
  provider          = aws.replica_region
  name              = "/g2team8/log_group"
  retention_in_days = 5
}

resource "aws_cloudwatch_log_stream" "gs_hack-stream_replica" {
  provider       = aws.replica_region
  name           = "/g2team8/log_stream"
  log_group_name = aws_cloudwatch_log_group.g2team8_replica.name
}
