# Dev environment infrastructure configuration.
module "stack" {
  source = "../../modules/stack"

  project_id    = var.project_id
  region        = var.region
  app_name      = var.app_name
  github_repo   = var.github_repo
  environment   = "dev"
  deploy_branch = "develop"

  # Sized for PostGIS development dataset (10 GB).
  deletion_protection   = false
  sql_tier              = "db-g1-small" # "db-custom-1-3840"
  sql_disk_size         = 30
  sql_availability_type = "ZONAL"
  min_instances         = 0
  max_instances         = 3

  enable_cloud_sql                   = true
  external_cloud_sql_connection_name = var.shared_cloud_sql_connection_name
  shared_db_name                     = "permica-gis"
  shared_db_user                     = "dev_user"
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


  # Developers can deploy, read logs and add secret values in dev.
  developer_members = var.developer_members
  developer_roles = [
    "roles/viewer",
    "roles/logging.viewer",
    "roles/run.developer",
    "roles/cloudsql.client",
    "roles/secretmanager.secretVersionAdder",
    "roles/storage.objectUser",
  ]

  admin_members = var.admin_members
  admin_roles = [
    "roles/run.admin",
    "roles/cloudsql.admin",
    "roles/secretmanager.admin",
    "roles/storage.admin",
    "roles/bigtable.admin",
  ]
}
