# -----------------------------------
# Security Group for RDS PostgreSQL
# -----------------------------------

resource "aws_security_group" "demo_backend_postgresql_sg" {
  name   = "demo-backend-db-sg"
  vpc_id = data.aws_vpc.main_vpc.id

  ingress {
    description     = "Allow HTTP access from demo backend service"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.demo_backend_task_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demo-backend-demo-backend-postgresql-sg"
  }
}

# DB Subnet Group (tells RDS which subnets to use)
resource "aws_db_subnet_group" "demo_backend_subnet_group" {
  name       = "demo-backend-db-subnet-group"
  subnet_ids = data.aws_subnets.private_subnets.ids

  tags = { Name = "demo-backend-db-subnet-group" }
}

data "aws_subnet" "demo_backend_target_subnet" {
  id = data.aws_subnets.private_subnets.ids[0]
}

# The RDS PostgreSQL Instance
resource "aws_db_instance" "demo_backend_postgresql" {
  identifier                      = "demo-backend-db"
  engine                          = "postgres"
  engine_version                  = local.postgresql.engine_version
  instance_class                  = local.postgresql.instance_class
  allocated_storage               = local.postgresql.allocated_storage
  db_name                         = local.postgresql.db_name
  username                        = local.postgresql.username
  password                        = aws_ssm_parameter.postgresql_admin_password.value
  db_subnet_group_name            = aws_db_subnet_group.demo_backend_subnet_group.name
  availability_zone               = data.aws_subnet.demo_backend_target_subnet.availability_zone
  vpc_security_group_ids          = [aws_security_group.demo_backend_postgresql_sg.id]
  skip_final_snapshot             = true
  publicly_accessible             = false
  enabled_cloudwatch_logs_exports = ["postgresql"]
}

resource "aws_ssm_parameter" "postgresql_admin_password" {
  name        = "/postgresql/admin_password"
  description = "Postgresql admin password"
  type        = "SecureString"
  value       = local.postgresql.password

  tags = {
    Name = "demo-backend-postgresql-admin-password"
  }
}
