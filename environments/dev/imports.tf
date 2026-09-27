# Declarative imports for pre-existing dev infrastructure resources
# Dynamically uses var.project_id to prevent hardcoding project IDs

import {
  to = module.stack.module.iam.google_service_account.runtime
  id = "projects/${var.project_id}/serviceAccounts/${var.app_name}-dev-runtime@${var.project_id}.iam.gserviceaccount.com"
}

import {
  to = module.stack.module.iam.google_service_account.deployer
  id = "projects/${var.project_id}/serviceAccounts/${var.app_name}-dev-deployer@${var.project_id}.iam.gserviceaccount.com"
}

import {
  to = module.stack.module.secrets[0].google_secret_manager_secret.managed["jwt-secret"]
  id = "projects/${var.project_id}/secrets/jwt-secret"
}

import {
  to = module.stack.module.secrets[0].google_secret_manager_secret.db_password
  id = "projects/${var.project_id}/secrets/db-password"
}

import {
  to = module.stack.module.artifact_registry[0].google_artifact_registry_repository.docker
  id = "projects/${var.project_id}/locations/${var.region}/repositories/${var.app_name}-dev"
}

import {
  to = module.stack.module.cloud_sql[0].google_sql_database_instance.this
  id = "projects/${var.project_id}/instances/${var.app_name}-dev-postgres"
}

import {
  to = module.stack.module.storage[0].google_storage_bucket.this
  id = "projects/${var.project_id}/buckets/${var.project_id}-data"
}
