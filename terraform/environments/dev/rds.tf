resource "aws_db_subnet_group" "shelful_dev" {
  name        = "shelful-dev-rds-subnet-group"
  description = "Shelful dev RDS private subnet group"

  subnet_ids = [
    aws_subnet.private_1a.id,
    aws_subnet.private_1b.id,
  ]
}

resource "aws_db_instance" "shelful_dev_postgres" {
  identifier = "shelful-dev-postgres"

  engine         = "postgres"
  engine_version = "17.11"
  instance_class = "db.t4g.micro"

  allocated_storage   = 20
  storage_type        = "gp3"
  storage_encrypted   = true
  iops                = 3000
  storage_throughput  = 125
  skip_final_snapshot = true

  db_subnet_group_name = aws_db_subnet_group.shelful_dev.name

  vpc_security_group_ids = [
    aws_security_group.rds.id,
  ]

  port                = 5432
  publicly_accessible = false
  multi_az            = false

  backup_retention_period    = 1
  auto_minor_version_upgrade = true

  deletion_protection   = false
  copy_tags_to_snapshot = true

  performance_insights_enabled = true
  monitoring_interval          = 0

  tags = {
    Name        = "shelful-dev-postgres"
    Environment = "dev"
    Project     = "shelful"
  }
}
