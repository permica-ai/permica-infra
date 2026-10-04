module "stack" {
  source = "../../modules/stack"

  project_id    = var.project_id
  region        = var.region
  app_name      = var.app_name
  github_repo   = var.github_repo
  environment   = "prod"
  deploy_branch = "main"

  # Sized and protected for production PostGIS workloads (10+ GB dataset).
  deletion_protection   = true
  sql_tier              = "db-custom-2-7680"
  sql_availability_type = "REGIONAL"
  sql_disk_size         = 50
  min_instances         = 1
  max_instances         = 10
  memory                = "1Gi"

  enable_cloud_sql                   = var.enable_cloud_sql
  external_cloud_sql_connection_name = var.shared_cloud_sql_connection_name
  shared_db_name                     = "permica-gis"
  shared_db_user                     = "prod_user"
  enable_cloud_run                   = var.enable_cloud_run
  enable_storage                     = var.enable_storage
  enable_artifact_registry           = var.enable_artifact_registry
  enable_scheduler                   = var.enable_scheduler
  enable_secrets                     = var.enable_secrets
  enable_bigtable                    = var.enable_bigtable
  bigtable_tables                    = var.bigtable_tables
  scheduler_jobs                     = var.scheduler_jobs
  extra_secret_env                   = var.extra_secret_env
  allow_public_access                = var.allow_public_access


  # Developers get read-only access to prod. Changes go through PRs + CI.
  developer_members = var.developer_members
  developer_roles = [
    "roles/viewer",
    "roles/logging.viewer",
  ]

  # Admins are for break-glass operations (e.g. adding secret values).
  admin_members = var.admin_members
  admin_roles = [
    "roles/run.admin",
    "roles/cloudsql.admin",
    "roles/secretmanager.admin",
  ]
}
