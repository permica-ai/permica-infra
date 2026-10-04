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

output "dev_db_password_secret_id" {
  value       = google_secret_manager_secret.dev_db_password.id
  description = "Secret Manager secret resource path for dev DB password."
}

output "prod_db_password_secret_id" {
  value       = google_secret_manager_secret.prod_db_password.id
  description = "Secret Manager secret resource path for prod DB password."
}

output "app_deploy_github_variables" {
  description = "Shared Cloud SQL configuration variables for application repos."
  value = {
    GCP_SHARED_CLOUD_SQL_CONNECTION_NAME = module.cloud_sql.connection_name
    GCP_SHARED_DB_NAME                   = module.cloud_sql.database_name
    GCP_SHARED_DB_USER                   = module.cloud_sql.user_name
    GCP_SHARED_DB_PASSWORD_SECRET_DEV    = google_secret_manager_secret.dev_db_password.id
    GCP_SHARED_DB_PASSWORD_SECRET_PROD   = google_secret_manager_secret.prod_db_password.id
  }
}

