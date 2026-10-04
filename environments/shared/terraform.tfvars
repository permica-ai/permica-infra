project_id    = "permica-ai-shared-ebcee8" # matches bootstrap shared_project_id
region        = "us-east1"
app_name      = "permica-ai"
database_name = "permica-gis"

# Cost-optimized starting configuration (~$50/mo). Scale up anytime later without data loss.
sql_tier              = "db-custom-1-3840" # 1 vCPU, 3.75 GB RAM
sql_availability_type = "ZONAL"
sql_disk_size         = 30

developer_members = []
admin_members     = []

