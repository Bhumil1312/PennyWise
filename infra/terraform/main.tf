terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cockroachdb = {
      source  = "cockroachdb/cockroachdb"
      version = "~> 1.0"
    }
  }
  backend "s3" {
    bucket         = "pennywise-terraform-state"
    key            = "pennywise/production/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "pennywise-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

provider "cockroachdb" {
  api_key = var.cockroachdb_api_key
}

locals {
  name_prefix = "pennywise-${var.environment}"
  common_tags = {
    Project     = "PennyWise"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = var.environment != "production"

  tags = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  name          = "${local.name_prefix}-eks"
  environment   = var.environment
  vpc_id        = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  node_desired_size = var.eks_node_desired_size
  node_max_size = var.eks_node_max_size
  tags          = local.common_tags
}

module "msk" {
  source = "./modules/msk"

  name            = "${local.name_prefix}-msk"
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  instance_type   = var.msk_instance_type
  broker_count    = var.msk_broker_count
  tags            = local.common_tags
}

module "redis" {
  source = "./modules/redis"

  name            = "${local.name_prefix}-redis"
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  node_type       = var.redis_node_type
  tags            = local.common_tags
}

module "cockroachdb" {
  source = "./modules/cockroachdb"

  name           = "${local.name_prefix}-crdb"
  environment    = var.environment
  cloud_provider = "AWS"
  cloud_region   = var.aws_region
  node_count     = var.crdb_node_count
  tags           = local.common_tags
}