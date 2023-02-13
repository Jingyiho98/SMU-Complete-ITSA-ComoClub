resource "aws_ecs_cluster" "g2team8_cluster_replica" {
  provider = aws.replica_region
  name     = "${var.namespace}-ecs-g2team8_cluster"
}
