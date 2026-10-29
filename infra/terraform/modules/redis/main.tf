variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "node_type" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name}-subnet"
  subnet_ids = var.private_subnets
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id          = var.name
  description                   = "PennyWise Redis cache (${var.environment})"
  node_type                     = var.node_type
  num_cache_clusters            = 1
  port                          = 6379
  automatic_failover_enabled    = false
  multi_az_enabled              = false
  subnet_group_name             = aws_elasticache_subnet_group.redis.name
  security_group_ids            = [aws_security_group.redis.id]
  engine                        = "redis"
  engine_version                = "7.1"
  parameter_group_name          = "default.redis7"
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true
  auto_minor_version_upgrade    = true

  tags = var.tags
}

resource "aws_security_group" "redis" {
  name   = "${var.name}-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

output "endpoint" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}