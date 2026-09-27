# Run ONCE, by a human, with your own gcloud credentials.
# Creates: the dev + prod projects, Terraform state buckets, GitHub OIDC
# (Workload Identity Federation) and the Terraform service accounts that CI uses.
# After this, everything else is applied by GitHub Actions.

terraform {
  required_version = ">= 1.16.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "google" {
  region = var.region
}

# Unique suffix generator for project IDs (<app>-<env>-<id>)
resource "random_id" "project_suffix" {
  byte_length = 3
}

locals {
  envs = {
    dev  = { project_id = coalesce(var.dev_project_id, "${var.app_name}-dev-${random_id.project_suffix.hex}"), deploy_branch = var.dev_branch }
    prod = { project_id = coalesce(var.prod_project_id, "${var.app_name}-prod-${random_id.project_suffix.hex}"), deploy_branch = var.prod_branch }
  }

  bootstrap_apis = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
  ]

  env_apis = {
    for pair in setproduct(keys(local.envs), local.bootstrap_apis) :
    "${pair[0]}/${pair[1]}" => { env = pair[0], api = pair[1] }
  }

  # Read-only roles for the "plan" service account used on pull requests.
  plan_roles = [
    "roles/viewer",
    "roles/iam.securityReviewer",
    "roles/secretmanager.secretAccessor",
  ]

  plan_bindings = {
    for pair in setproduct(keys(local.envs), local.plan_roles) :
    "${pair[0]}/${pair[1]}" => { env = pair[0], role = pair[1] }
  }
}

# ---------------------------------------------------------------- projects
resource "google_project" "env" {
  for_each = local.envs

  name                = "${var.app_name}-${each.key}"
  project_id          = each.value.project_id
  billing_account     = var.billing_account
  org_id              = var.org_id
  folder_id           = var.folder_id
  auto_create_network = false
  deletion_policy     = "DELETE"

  labels = {
    app         = var.app_name
    environment = each.key
  }
}

resource "google_project_service" "bootstrap" {
  for_each = local.env_apis

  project            = google_project.env[each.value.env].project_id
  service            = each.value.api
  disable_on_destroy = false
}

# ------------------------------------------------------------ state buckets
resource "google_storage_bucket" "state" {
  for_each = local.envs

  name                        = "${each.value.project_id}-tfstate"
  project                     = google_project.env[each.key].project_id
  location                    = var.state_bucket_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = each.key == "prod" ? false : true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.bootstrap]
}

# -------------------------------------------------- Terraform service accounts
resource "google_service_account" "apply" {
  for_each = local.envs

  project      = google_project.env[each.key].project_id
  account_id   = "tf-apply"
  display_name = "Terraform apply (${each.key})"

  depends_on = [google_project_service.bootstrap]
}

resource "google_service_account" "plan" {
  for_each = local.envs

  project      = google_project.env[each.key].project_id
  account_id   = "tf-plan"
  display_name = "Terraform plan, read-only (${each.key})"

  depends_on = [google_project_service.bootstrap]
}

# Terraform needs to create IAM bindings, so the apply account is project Owner.
# It can only be impersonated from the configured branch (see WIF binding below).
resource "google_project_iam_member" "apply_owner" {
  for_each = local.envs

  project = google_project.env[each.key].project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.apply[each.key].email}"
}

resource "google_project_iam_member" "plan" {
  for_each = local.plan_bindings

  project = google_project.env[each.value.env].project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.plan[each.value.env].email}"
}

# The plan account must read state and take the state lock.
resource "google_storage_bucket_iam_member" "plan_state" {
  for_each = local.envs

  bucket = google_storage_bucket.state[each.key].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.plan[each.key].email}"
}

# ---------------------------------------- GitHub OIDC (Workload Identity Federation)
resource "google_iam_workload_identity_pool" "github" {
  for_each = local.envs

  project                   = google_project.env[each.key].project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.bootstrap]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  for_each = local.envs

  project                            = google_project.env[each.key].project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[each.key].workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.repo_ref"   = "assertion.repository + '@' + assertion.ref"
  }

  # Tokens from any other repository are rejected outright.
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Apply: only this repo AND only the environment's deploy branch.
resource "google_service_account_iam_member" "apply_wif" {
  for_each = local.envs

  service_account_id = google_service_account.apply[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[each.key].name}/attribute.repo_ref/${var.github_repo}@refs/heads/${each.value.deploy_branch}"
}

# Plan (read-only): any ref in this repo, so pull requests can run plans.
resource "google_service_account_iam_member" "plan_wif" {
  for_each = local.envs

  service_account_id = google_service_account.plan[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[each.key].name}/attribute.repository/${var.github_repo}"
}


