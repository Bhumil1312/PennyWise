output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "msk_bootstrap_brokers" {
  value     = module.msk.bootstrap_brokers
  sensitive = true
}

output "redis_endpoint" {
  value = module.redis.endpoint
}

output "cockroachdb_connection_string" {
  value     = module.cockroachdb.connection_string
  sensitive = true
}