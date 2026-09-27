output "github_variables" {
  description = "Create these as GitHub repository VARIABLES (Settings > Secrets and variables > Actions > Variables). They are identifiers, not secrets."
  value = merge(
    { for k, v in local.envs : "GCP_PROJECT_ID_${upper(k)}" => v.project_id },
    { for k in keys(local.envs) : "GCP_WIF_PROVIDER_${upper(k)}" => try(google_iam_workload_identity_pool_provider.github[k].name, null) },
    { for k in keys(local.envs) : "GCP_TF_APPLY_SA_${upper(k)}" => try(google_service_account.apply[k].email, null) },
    { for k in keys(local.envs) : "GCP_TF_PLAN_SA_${upper(k)}" => try(google_service_account.plan[k].email, null) },
  )
}

output "state_buckets" {
  value = { for k in keys(local.envs) : k => try(google_storage_bucket.state[k].name, null) }
}
