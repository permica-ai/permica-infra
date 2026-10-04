output "cloud_run_url" {
  value = var.enable_cloud_run ? module.cloud_run[0].uri : null
}

output "cloud_sql_connection_name" {
  value = local.has_cloud_sql ? local.sql_connection_name : null
}

output "artifact_registry_path" {
  description = "Push images here: <path>/backend:<tag>"
  value       = var.enable_artifact_registry ? "${var.region}-docker.pkg.dev/${var.project_id}/${module.artifact_registry[0].repository_id}" : null
}

output "runtime_service_account" {
  value = module.iam.runtime_email
}

output "deployer_service_account" {
  value = module.iam.deployer_email
}

output "api_gateway_url" {
  description = "The public URL host of the API Gateway proxy"
  value       = (var.enable_api_gateway && var.enable_cloud_run) ? module.api_gateway[0].gateway_url : null
}

output "api_gateway_key" {
  description = "The GCP API key for API Gateway"
  value       = (var.enable_api_gateway && var.enable_cloud_run) ? module.api_gateway[0].api_key : null
  sensitive   = true
}


output "app_deploy_github_variables" {
  description = "Set these as GitHub variables in the repo that builds/deploys the app (suffix with _DEV / _PROD)."
  value = {
    GCP_REGION                     = var.region
    GCP_PROJECT_ID                 = var.project_id
    GCP_WIF_PROVIDER               = "${data.google_iam_workload_identity_pool.github.name}/providers/github"
    GCP_DEPLOYER_SA                = module.iam.deployer_email
    GCP_RUNTIME_SA                 = module.iam.runtime_email
    ARTIFACT_REGISTRY              = var.enable_artifact_registry ? "${var.region}-docker.pkg.dev/${var.project_id}/${module.artifact_registry[0].repository_id}" : ""
    CLOUD_RUN_SERVICE              = var.enable_cloud_run ? module.cloud_run[0].name : ""
    API_GATEWAY_URL                = (var.enable_api_gateway && var.enable_cloud_run) ? module.api_gateway[0].gateway_url : ""
    CLOUD_SQL_CONNECTION_NAME      = local.has_cloud_sql ? local.sql_connection_name : ""
    DB_NAME                        = local.has_cloud_sql ? local.sql_db_name : ""
    DB_USER                        = local.has_cloud_sql ? local.sql_user_name : ""
    DB_SOCKET_DIR                  = "/cloudsql"
    DATABASE_URL                   = local.has_cloud_sql ? "postgresql://${local.sql_user_name}@/${local.sql_db_name}?host=/cloudsql/${local.sql_connection_name}" : ""
    SPATIAL_DATABASE_URL           = var.external_cloud_sql_connection_name != "" ? "postgresql://${var.shared_db_user != "" ? var.shared_db_user : "dev_user"}@/${var.shared_db_name != "" ? var.shared_db_name : "permica-gis"}?host=/cloudsql/${var.external_cloud_sql_connection_name}" : ""
    SPATIAL_BACKEND_DSN_SHARED_GIS = var.external_cloud_sql_connection_name != "" ? "postgresql://${var.shared_db_user != "" ? var.shared_db_user : "dev_user"}@/${var.shared_db_name != "" ? var.shared_db_name : "permica-gis"}?host=/cloudsql/${var.external_cloud_sql_connection_name}" : ""
  }
}


