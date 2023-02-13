resource "aws_sqs_queue" "failover_queue_replica" {
  provider                    = aws.replica_region
  name                        = "failover-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  kms_master_key_id           = aws_kms_key.replica.key_id
  delay_seconds               = 300
}
