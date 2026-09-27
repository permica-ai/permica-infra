project_id  = "permica-ai-dev-256b4a" # must match bootstrap dev_project_id
region      = "us-east1"
app_name    = "permica-ai"
github_repo = "permica-ai/permica-infra" # repo that builds/deploys the app

# Use Google Groups so adding a teammate never requires a Terraform change.
# Without Workspace/Cloud Identity, list individuals instead: "user:jane@gmail.com"
developer_members = []
admin_members     = []

# Bigtable costs roughly a node's price 24/7. Set true only if dev needs it.
enable_bigtable = false

# bigtable_tables = { events = { column_families = ["cf1"] } }
# scheduler_jobs  = { nightly-cleanup = { schedule = "0 3 * * *", path = "/tasks/cleanup" } }
