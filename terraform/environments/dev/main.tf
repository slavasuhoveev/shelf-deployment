resource "aws_vpc" "shelful_dev" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "shelful-dev-vpc"
  }
}

resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.shelful_dev.id
  cidr_block              = "10.0.0.0/20"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "shelful-dev-subnet-public1-eu-central-1a"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.shelful_dev.id
  cidr_block              = "10.0.16.0/20"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "shelful-dev-subnet-public2-eu-central-1b"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private_1a" {
  vpc_id                  = aws_vpc.shelful_dev.id
  cidr_block              = "10.0.128.0/20"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "shelful-dev-subnet-private1-eu-central-1a"
  }
}

resource "aws_subnet" "private_1b" {
  vpc_id                  = aws_vpc.shelful_dev.id
  cidr_block              = "10.0.144.0/20"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "shelful-dev-subnet-private2-eu-central-1b"
  }
}

resource "aws_internet_gateway" "shelful_dev" {
  vpc_id = aws_vpc.shelful_dev.id

  tags = {
    Name = "shelful-dev-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.shelful_dev.id

  tags = {
    Name = "shelful-dev-rtb-public"
  }
}

resource "aws_route_table" "private_1a" {
  vpc_id = aws_vpc.shelful_dev.id

  tags = {
    Name = "shelful-dev-rtb-private1-eu-central-1a"
  }
}

resource "aws_route_table" "private_1b" {
  vpc_id = aws_vpc.shelful_dev.id

  tags = {
    Name = "shelful-dev-rtb-private2-eu-central-1b"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.shelful_dev.id
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private_1a.id
}

resource "aws_route_table_association" "private_1b" {
  subnet_id      = aws_subnet.private_1b.id
  route_table_id = aws_route_table.private_1b.id
}

resource "aws_security_group" "rds" {
  name        = "shelful-dev-rds-sg"
  description = "Security group for Shelful dev RDS PostgreSQL"
  vpc_id      = aws_vpc.shelful_dev.id

  tags = {
    Name        = "shelful-dev-rds-sg"
    Environment = "dev"
    Project     = "shelful"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_postgres_from_eks" {
  security_group_id = aws_security_group.rds.id

  referenced_security_group_id = "sg-034c4b27090119c0b"

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432
}

resource "aws_vpc_security_group_egress_rule" "rds_all_ipv4" {
  security_group_id = aws_security_group.rds.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
