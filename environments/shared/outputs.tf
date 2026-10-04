output "connection_name" {
  value       = module.cloud_sql.connection_name
  description = "Shared Cloud SQL connection name (project:region:instance)."
}

output "database_name" {
  value       = module.cloud_sql.database_name
  description = "Shared PostgreSQL database name."
}

output "dev_user" {
  value       = "dev_user"
  description = "DB user for Dev environment."
}

output "prod_user" {
  value       = "prod_user"
  description = "DB user for Prod environment."
}

output "app_deploy_github_variables" {
  description = "Shared Cloud SQL configuration variables for application repos."
  value = {
    GCP_SHARED_CLOUD_SQL_CONNECTION_NAME = module.cloud_sql.connection_name
    GCP_SHARED_DB_NAME                   = module.cloud_sql.database_name
  }
}

