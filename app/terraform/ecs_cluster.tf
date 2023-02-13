resource "aws_ecs_cluster" "g2team8_cluster" {
  name = "${var.namespace}-ecs-g2team8_cluster"
}
