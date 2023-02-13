resource "aws_sqs_queue" "failover_queue" {
  name                        = "failover-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  kms_master_key_id           = aws_kms_key.default.key_id
  delay_seconds               = 300
}
