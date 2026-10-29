variable "environment" {
  description = "Deployment environment (development/staging/production)"
  type        = string
  default     = "development"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "eks_node_desired_size" {
  type    = number
  default = 2
}

variable "eks_node_max_size" {
  type    = number
  default = 6
}

variable "msk_instance_type" {
  type    = string
  default = "kafka.m5.large"
}

variable "msk_broker_count" {
  type    = number
  default = 3
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "crdb_node_count" {
  type    = number
  default = 3
}

variable "cockroachdb_api_key" {
  description = "CockroachDB Cloud API key (set via TF_VAR_cockroachdb_api_key)"
  type        = string
  sensitive   = true
}