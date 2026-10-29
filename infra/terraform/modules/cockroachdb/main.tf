variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cloud_provider" {
  type = string
}

variable "cloud_region" {
  type = string
}

variable "node_count" {
  type = number
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "cockroachdb_cluster" "main" {
  name           = var.name
  cloud_provider = var.cloud_provider
  cloud_region   = var.cloud_region
  serverless     = false

  dedicated {
    storage_gib = 50
    num_virtual_cpus = 2
    memory_gib  = 8
  }
}

resource "cockroachdb_sql_user" "app" {
  name        = "pennywise"
  cluster_id  = cockroachdb_cluster.main.id
  password    = random_password.app.result
}

resource "random_password" "app" {
  length  = 24
  special = false
}

resource "cockroachdb_allow_list" "main" {
  cluster_id = cockroachdb_cluster.main.id
  name       = "pennywise-app"
  cidr_block = "0.0.0.0/0"
}

output "connection_string" {
  value     = "postgresql://${cockroachdb_sql_user.app.name}:${random_password.app.result}@${cockroachdb_cluster.main.sql_dns}:26257/pennywise?sslmode=verify-full"
  sensitive = true
}

output "cluster_id" {
  value = cockroachdb_cluster.main.id
}