project_id  = "permica-ai-prod-134567" # must match bootstrap prod_project_id
region      = "us-east1"
app_name    = "permica-ai"
github_repo = "permica-ai/permica-infra" # repo that builds/deploys the app

developer_members = []
admin_members     = []

enable_bigtable = true

# bigtable_tables = { events = { column_families = ["cf1"] } }
# scheduler_jobs  = { nightly-cleanup = { schedule = "0 3 * * *", path = "/tasks/cleanup" } }
