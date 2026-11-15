locals {
  name = "lsk-${var.service_name}-${var.environment}"
  azs = slice(data.aws_availability_zones.available.names,0,2)
  prod = var.environment == "prod"
  tags = { "lsk-data-region" = var.region }
}
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = { Name = "${local.name}-vpc" }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${local.name}-igw" }
}
resource "aws_subnet" "public" {
  count = 2
  vpc_id = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block = cidrsubnet(var.vpc_cidr,4,count.index)
  map_public_ip_on_launch = false
  tags = { Name = "${local.name}-public-${count.index}" }
}
resource "aws_subnet" "private" {
  count = 2
  vpc_id = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block = cidrsubnet(var.vpc_cidr,4,count.index+2)
  tags = { Name = "${local.name}-private-${count.index}" }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
resource "aws_route_table_association" "public" {
  count = 2
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_eip" "nat" {
  count = local.prod ? 2 : 1
  domain = "vpc"
  depends_on = [aws_internet_gateway.igw]
}
resource "aws_nat_gateway" "nat" {
  count = local.prod ? 2 : 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id = aws_subnet.public[count.index].id
}
resource "aws_route_table" "private" {
  count = 2
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[local.prod ? count.index : 0].id
  }
}
resource "aws_route_table_association" "private" {
  count = 2
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
resource "aws_security_group" "alb" {
  name_prefix = "${local.name}-alb-"
  vpc_id = aws_vpc.main.id
  ingress {
    description = "Corporate HTTPS only, CIDRs explicitly supplied"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "app" {
  name_prefix = "${local.name}-app-"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "db" {
  name_prefix = "${local.name}-db-"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = [aws_security_group.app.id]
  }
}
resource "aws_db_subnet_group" "db" {
  name = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.private[*].id
}
resource "aws_db_instance" "db" {
  identifier = "${local.name}-postgres"
  engine = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class
  allocated_storage = local.prod ? 100 : 20
  max_allocated_storage = local.prod ? 500 : 100
  storage_type = "gp3"
  storage_encrypted = true
  db_name = "platform"
  username = "app"
  password = var.db_password
  multi_az = local.prod
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  backup_retention_period = var.db_backup_retention_days
  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = !local.prod
  final_snapshot_identifier = local.prod ? "${local.name}-final" : null
  apply_immediately = !local.prod
  lifecycle {
    precondition {
      condition = !local.prod || (
        var.db_deletion_protection &&
        var.db_backup_retention_days >= 7 &&
        var.desired_count >= 2 &&
        var.db_instance_class != "db.t4g.micro"
      )
      error_message = "Production requires DB deletion protection, >=7d backups, >=2 ECS tasks, non-micro DB."
    }
  }
}
resource "aws_ecr_repository" "app" {
  name = local.name
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  force_delete = false
}
resource "aws_cloudwatch_log_group" "app" {
  name = "/lsk/${local.name}"
  retention_in_days = local.prod ? 90 : 14
}
data "aws_iam_policy_document" "assume_task" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "execution" {
  name = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.assume_task.json
}
resource "aws_iam_role_policy_attachment" "execution" {
  role = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "task" {
  name = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.assume_task.json
}
resource "aws_secretsmanager_secret" "db_url" {
  name = "${local.name}-database-url"
  recovery_window_in_days = local.prod ? 30 : 7
}
resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id = aws_secretsmanager_secret.db_url.id
  secret_string = "postgresql+psycopg://app:${urlencode(var.db_password)}@${aws_db_instance.db.address}:5432/platform"
}
resource "aws_iam_role_policy" "runtime_secrets" {
  name = "${local.name}-secrets"
  role = aws_iam_role.execution.id
  policy = jsonencode({Version="2012-10-17",Statement=[
    {Effect="Allow",Action=["secretsmanager:GetSecretValue"],Resource=[aws_secretsmanager_secret.db_url.arn]}
  ]})
}
resource "aws_ecs_cluster" "app" {
  name = local.name
  setting {
    name = "containerInsights"
    value = "enabled"
  }
}
resource "aws_ecs_task_definition" "app" {
  family = local.name
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = var.ecs_cpu
  memory = var.ecs_memory
  execution_role_arn = aws_iam_role.execution.arn
  task_role_arn = aws_iam_role.task.arn
  container_definitions = jsonencode([{
    name = "api", image = var.image, essential = true,
    portMappings = [{containerPort=8080,protocol="tcp"}],
    secrets = [{name="DATABASE_URL",valueFrom=aws_secretsmanager_secret.db_url.arn}],
    environment = [
      {name="OIDC_ISSUER",value=var.oidc_issuer},
      {name="OIDC_AUDIENCE",value=var.oidc_audience},
      {name="OIDC_JWKS_URL",value=var.oidc_jwks_url},
      {name="LSK_ENFORCE_RESIDENCY",value="true"},
      {name="LSK_DEPLOYMENT_REGION",value=var.region},
      {name="LSK_TENANT_REGION_POLICY",value=jsonencode(var.tenant_region_policy)}
    ],
    logConfiguration={logDriver="awslogs",options={
      "awslogs-group"=aws_cloudwatch_log_group.app.name,
      "awslogs-region"=var.region,"awslogs-stream-prefix"="api"
    }}
  }])
}
resource "aws_lb" "internal" {
  name = "${local.name}-alb"
  internal = true
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb.id]
  subnets = aws_subnet.private[*].id
  enable_deletion_protection = local.prod
}
resource "aws_lb_target_group" "api" {
  name = "${local.name}-api"
  port = 8080
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/readyz"
    matcher = "200"
    healthy_threshold = 2
    unhealthy_threshold = 3
  }
}
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.internal.arn
  port = 443
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = var.certificate_arn
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}
resource "aws_ecs_service" "api" {
  name = local.name
  cluster = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count = var.desired_count
  launch_type = "FARGATE"
  platform_version = "LATEST"
  enable_execute_command = false
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent = 200
  health_check_grace_period_seconds = 120
  network_configuration {
    subnets = aws_subnet.private[*].id
    security_groups = [aws_security_group.app.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name = "api"
    container_port = 8080
  }
  depends_on = [aws_lb_listener.https,aws_iam_role_policy.runtime_secrets,aws_iam_role_policy_attachment.execution]
}
output "internal_alb_dns" { value = aws_lb.internal.dns_name }
output "ecr_repository_url" { value = aws_ecr_repository.app.repository_url }
output "ecs_cluster_name" { value = aws_ecs_cluster.app.name }
output "ecs_task_family" { value = aws_ecs_task_definition.app.family }
output "private_subnet_ids" { value = aws_subnet.private[*].id }

output "app_security_group_id" { value = aws_security_group.app.id }
