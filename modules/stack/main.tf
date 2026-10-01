# One complete environment (dev or prod). environments/dev and environments/prod
# both call this module, so the two stay structurally identical and only differ
# in the values they pass.

locals {
  prefix = "${var.app_name}-${var.environment}"

  labels = {
    app         = var.app_name
    environment = var.environment
    managed_by  = "terraform"
  }

  services = [
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "bigtable.googleapis.com",
    "bigtableadmin.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "logging.googleapis.com",
    "bigquery.googleapis.com",
    "apigateway.googleapis.com",
    "servicemanagement.googleapis.com",
  ]
}

# Created by bootstrap/.
data "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github"
}

module "apis" {
  source = "../apis"

  project_id = var.project_id
  services   = local.services
}

module "iam" {
  source = "../iam"

  project_id        = var.project_id
  app_name          = var.app_name
  environment       = var.environment
  github_repo       = var.github_repo
  deploy_branch     = var.deploy_branch
  wif_pool_name     = data.google_iam_workload_identity_pool.github.name
  enable_bigtable   = var.enable_bigtable
  developer_members = var.developer_members
  developer_roles   = var.developer_roles
  admin_members     = var.admin_members
  admin_roles       = var.admin_roles

  depends_on = [module.apis]
}

module "artifact_registry" {
  count  = var.enable_artifact_registry ? 1 : 0
  source = "../artifact-registry"

  project_id    = var.project_id
  region        = var.region
  name          = local.prefix
  writer_member = "serviceAccount:${module.iam.deployer_email}"
  labels        = local.labels

  depends_on = [module.apis]
}

module "cloud_sql" {
  count  = var.enable_cloud_sql ? 1 : 0
  source = "../cloud-sql"

  project_id          = var.project_id
  region              = var.region
  name                = "${local.prefix}-postgres"
  tier                = var.sql_tier
  availability_type   = var.sql_availability_type
  disk_size           = var.sql_disk_size
  database_name       = var.app_name
  deletion_protection = var.deletion_protection
  labels              = local.labels

  depends_on = [module.apis]
}

module "storage" {
  count  = var.enable_storage ? 1 : 0
  source = "../cloud-storage"

  project_id         = var.project_id
  name               = "${var.project_id}-data"
  location           = var.region
  force_destroy      = !var.deletion_protection
  object_user_member = "serviceAccount:${module.iam.runtime_email}"
  labels             = local.labels

  depends_on = [module.apis]
}

module "bigtable" {
  count  = var.enable_bigtable ? 1 : 0
  source = "../bigtable"

  project_id          = var.project_id
  name                = "${local.prefix}-bt"
  zone                = "${var.region}-b"
  num_nodes           = var.bigtable_num_nodes
  storage_type        = var.bigtable_storage_type
  tables              = var.bigtable_tables
  deletion_protection = var.deletion_protection
  labels              = local.labels

  depends_on = [module.apis]
}

module "secrets" {
  count  = var.enable_secrets ? 1 : 0
  source = "../secret-manager"

  project_id      = var.project_id
  secret_ids      = var.app_secrets
  accessor_member = "serviceAccount:${module.iam.runtime_email}"
  db_password     = var.enable_cloud_sql ? module.cloud_sql[0].password : ""
  labels          = local.labels

  depends_on = [module.apis]
}

module "cloud_run" {
  count  = var.enable_cloud_run ? 1 : 0
  source = "../cloud-run"

  project_id            = var.project_id
  region                = var.region
  name                  = "${local.prefix}-api"
  image                 = var.container_image
  service_account_email = module.iam.runtime_email
  cpu                   = var.cpu
  memory                = var.memory
  min_instances         = var.min_instances
  max_instances         = var.max_instances
  allow_public_access   = var.allow_public_access
  deletion_protection   = var.deletion_protection
  labels                = local.labels

  enable_cloud_sql          = var.enable_cloud_sql
  cloud_sql_connection_name = var.enable_cloud_sql ? module.cloud_sql[0].connection_name : ""

  env_vars = merge(
    {
      ENVIRONMENT = var.environment
      GCP_PROJECT = var.project_id
    },
    var.enable_cloud_sql ? {
      DB_INSTANCE_CONNECTION_NAME = module.cloud_sql[0].connection_name
      DB_SOCKET_DIR               = "/cloudsql"
      DB_NAME                     = module.cloud_sql[0].database_name
      DB_USER                     = module.cloud_sql[0].user_name
    } : {},
    var.enable_storage ? { STORAGE_BUCKET = module.storage[0].name } : {},
    var.enable_bigtable ? { BIGTABLE_INSTANCE_ID = module.bigtable[0].instance_name } : {},
  )

  secret_env = merge(
    (var.enable_secrets && var.enable_cloud_sql) ? { DB_PASSWORD = module.secrets[0].db_password_secret_id } : {},
    var.extra_secret_env,
  )

  depends_on = [module.secrets, module.iam]
}

module "scheduler" {
  count  = (var.enable_scheduler && var.enable_cloud_run) ? 1 : 0
  source = "../scheduler"

  project_id   = var.project_id
  region       = var.region
  name_prefix  = local.prefix
  service_name = module.cloud_run[0].name
  service_uri  = module.cloud_run[0].uri
  jobs         = var.scheduler_jobs

  depends_on = [module.apis]
}

module "api_gateway" {
  count  = (var.enable_api_gateway && var.enable_cloud_run) ? 1 : 0
  source = "../api-gateway"

  project_id             = var.project_id
  region                 = var.region
  api_name               = var.app_name
  environment            = var.environment
  cloud_run_url          = module.cloud_run[0].uri
  cloud_run_service_name = module.cloud_run[0].name
  labels                 = local.labels

  depends_on = [module.apis, module.cloud_run]
}

