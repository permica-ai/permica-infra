# Declarative imports for pre-existing dev infrastructure resources

import {
  to = module.stack.module.iam.google_service_account.runtime
  id = "projects/permica-ai-dev-256b4a/serviceAccounts/permica-ai-dev-runtime@permica-ai-dev-256b4a.iam.gserviceaccount.com"
}

import {
  to = module.stack.module.iam.google_service_account.deployer
  id = "projects/permica-ai-dev-256b4a/serviceAccounts/permica-ai-dev-deployer@permica-ai-dev-256b4a.iam.gserviceaccount.com"
}

import {
  to = module.stack.module.secrets[0].google_secret_manager_secret.managed["jwt-secret"]
  id = "projects/permica-ai-dev-256b4a/secrets/jwt-secret"
}

import {
  to = module.stack.module.secrets[0].google_secret_manager_secret.db_password
  id = "projects/permica-ai-dev-256b4a/secrets/db-password"
}

import {
  to = module.stack.module.artifact_registry[0].google_artifact_registry_repository.app
  id = "projects/permica-ai-dev-256b4a/locations/us-east1/repositories/permica-ai-dev"
}

import {
  to = module.stack.module.cloud_sql[0].google_sql_database_instance.main
  id = "projects/permica-ai-dev-256b4a/instances/permica-ai-dev-postgres"
}

import {
  to = module.stack.module.storage[0].google_storage_bucket.app_data
  id = "projects/permica-ai-dev-256b4a/buckets/permica-ai-dev-256b4a-data"
}
