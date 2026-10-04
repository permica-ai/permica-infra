# Centralized Shared Cloud SQL (PostgreSQL 17 + PostGIS) Infrastructure
locals {
  prefix = "${var.app_name}-shared"

  labels = {
    app         = var.app_name
    environment = "shared"
    managed_by  = "terraform"
  }

  services = [
    "sqladmin.googleapis.com",
    "sql-component.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
  ]
}

module "apis" {
  source = "../../modules/apis"

  project_id = var.project_id
  services   = local.services
}

module "cloud_sql" {
  source = "../../modules/cloud-sql"

  project_id          = var.project_id
  region              = var.region
  name                = "${local.prefix}-postgres"
  tier                = var.sql_tier
  availability_type   = var.sql_availability_type
  disk_size           = var.sql_disk_size
  database_name       = var.database_name
  user_name           = "dev_user"
  additional_users    = ["prod_user"]
  deletion_protection = var.deletion_protection
  labels              = local.labels

  depends_on = [module.apis]
}

# Cross-project IAM: Grant dev & prod runtime service accounts roles/cloudsql.client
resource "google_project_iam_member" "dev_cloudsql_client" {
  count      = var.dev_service_account_email != "" ? 1 : 0
  project    = var.project_id
  role       = "roles/cloudsql.client"
  member     = "serviceAccount:${var.dev_service_account_email}"
  depends_on = [module.apis]
}

resource "google_project_iam_member" "prod_cloudsql_client" {
  count      = var.prod_service_account_email != "" ? 1 : 0
  project    = var.project_id
  role       = "roles/cloudsql.client"
  member     = "serviceAccount:${var.prod_service_account_email}"
  depends_on = [module.apis]
}

# Store database passwords in Secret Manager in shared project
resource "google_secret_manager_secret" "dev_db_password" {
  project    = var.project_id
  secret_id  = "dev-db-password"
  labels     = local.labels
  depends_on = [module.apis]

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "dev_db_password" {
  secret      = google_secret_manager_secret.dev_db_password.id
  secret_data = module.cloud_sql.user_passwords["dev_user"]
}

resource "google_secret_manager_secret" "prod_db_password" {
  project    = var.project_id
  secret_id  = "prod-db-password"
  labels     = local.labels
  depends_on = [module.apis]

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "prod_db_password" {
  secret      = google_secret_manager_secret.prod_db_password.id
  secret_data = module.cloud_sql.user_passwords["prod_user"]
}

