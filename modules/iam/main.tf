locals {
  prefix = "${var.app_name}-${var.environment}"

  # One binding per (member, role) pair. Members are usually Google Groups so
  # onboarding someone = adding them to the group, not editing Terraform.
  team_bindings = merge(
    {
      for pair in setproduct(var.developer_members, var.developer_roles) :
      "developer|${pair[0]}|${pair[1]}" => { member = pair[0], role = pair[1] }
    },
    {
      for pair in setproduct(var.admin_members, var.admin_roles) :
      "admin|${pair[0]}|${pair[1]}" => { member = pair[0], role = pair[1] }
    },
  )
}

# Identity the Cloud Run service runs as.
resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "${local.prefix}-runtime"
  display_name = "${local.prefix} Cloud Run runtime"
}

# Identity GitHub Actions uses to deploy the application (not Terraform).
resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = "${local.prefix}-deployer"
  display_name = "${local.prefix} app deployer (CI)"
}

# ---- runtime permissions (least privilege; bucket/secret access is granted on the resource itself)
resource "google_project_iam_member" "runtime_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_project_iam_member" "runtime_bigtable" {
  count = var.enable_bigtable ? 1 : 0

  project = var.project_id
  role    = "roles/bigtable.user"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_project_iam_member" "runtime_bigquery_jobuser" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_project_iam_member" "runtime_bigquery_dataeditor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# ---- deployer permissions
resource "google_project_iam_member" "deployer_run" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "deployer_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "deployer_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "deployer_cloudscheduler" {
  project = var.project_id
  role    = "roles/cloudscheduler.admin"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_service_account_iam_member" "deployer_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}

data "google_project" "project" {
  project_id = var.project_id
}

# Allow deployer SA to set compute SA on Cloud Scheduler jobs (OIDC token SA)
resource "google_service_account_iam_member" "deployer_act_as_compute" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}


# GitHub OIDC -> deployer: only this repo and only the environment's deploy branch.
resource "google_service_account_iam_member" "deployer_wif" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.wif_pool_name}/attribute.repository/${var.github_repo}"
}

# ---- human access
resource "google_project_iam_member" "team" {
  for_each = local.team_bindings

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}
