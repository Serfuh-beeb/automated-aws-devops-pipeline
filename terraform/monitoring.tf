# ---------- ECR Repos ----------

resource "aws_ecr_repository" "prometheus" {
  name         = "${var.project}-prometheus"
  force_delete = true
  tags         = { Name = "${var.project}-prometheus" }
}

resource "aws_ecr_repository" "grafana" {
  name         = "${var.project}-grafana"
  force_delete = true
  tags         = { Name = "${var.project}-grafana" }
}

# ---------- Cloud Map (Service Discovery) ----------

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "local"
  vpc  = aws_vpc.main.id
  tags = { Name = "${var.project}-namespace" }
}

resource "aws_service_discovery_service" "app" {
  name = "devops-project-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ---------- Security Group for Monitoring ----------

resource "aws_security_group" "monitoring" {
  name   = "${var.project}-monitoring-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port = 9090
    to_port   = 9090
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-monitoring-sg" }
}

# Allow monitoring SG to scrape ECS tasks
resource "aws_security_group_rule" "ecs_from_prometheus" {
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.monitoring.id
  security_group_id        = aws_security_group.ecs.id
}

# ---------- CloudWatch Log Groups ----------

resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/${var.project}-prometheus"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/${var.project}-grafana"
  retention_in_days = 7
}

# ---------- Prometheus Task Definition ----------

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.project}-prometheus"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_exec.arn

  container_definitions = jsonencode([{
    name      = "prometheus"
    image     = "${aws_ecr_repository.prometheus.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort = 9090, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.prometheus.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "prometheus"
      }
    }
  }])

  tags = { Name = "${var.project}-prometheus" }
}

# ---------- Grafana Task Definition ----------

resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.project}-grafana"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_exec.arn

  container_definitions = jsonencode([{
    name      = "grafana"
    image     = "${aws_ecr_repository.grafana.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "grafana"
      }
    }
  }])

  tags = { Name = "${var.project}-grafana" }
}

# ---------- ALB Target Groups ----------

resource "aws_lb_target_group" "grafana" {
  name        = "${var.project}-grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = { Name = "${var.project}-grafana-tg" }
}

# ---------- ALB Listener for Grafana (port 3000) ----------

resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.main.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

# ---------- ECS Services ----------

resource "aws_ecs_service" "prometheus" {
  name            = "${var.project}-prometheus"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.monitoring.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.prometheus.arn
  }

  tags = { Name = "${var.project}-prometheus" }
}

resource "aws_service_discovery_service" "prometheus" {
  name = "prometheus"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "grafana" {
  name            = "${var.project}-grafana"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.monitoring.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.grafana]

  tags = { Name = "${var.project}-grafana" }
}
