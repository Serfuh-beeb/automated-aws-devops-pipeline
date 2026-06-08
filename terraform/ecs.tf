resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7
  tags              = { Name = "${var.project}-logs" }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"
  tags = { Name = "${var.project}-cluster" }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_exec.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project}-api"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      environment = [
        { name = "DB_HOST", value = aws_db_instance.main.address },
        { name = "DB_USER", value = var.db_username },
        { name = "DB_PASSWORD", value = var.db_password },
        { name = "DB_NAME", value = var.db_name }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = { Name = "${var.project}-task" }
}

resource "aws_ecs_service" "app" {
  name            = "${var.project}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.project}-api"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = { Name = "${var.project}-service" }
}
