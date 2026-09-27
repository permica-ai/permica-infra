# Upgrading Components and Scaling Resources

This guide outlines how to upgrade infrastructure components (such as increasing Cloud SQL tier, disk size, CPU, or RAM) in **dev** and **prod** environments without losing data.

---

## 1. Overview & Data Safety Guarantees

In Terraform and Google Cloud Platform (GCP):
* **Cloud SQL Tier (CPU/RAM) Updates**: Modifying instance tier (`db-f1-micro` $\rightarrow$ `db-custom-2-7680` or `db-perf-optimized-N-2`) is an **in-place update**. Cloud SQL attaches the new compute resources to the existing persistent disk without destroying or re-creating the database.
* **Storage Disk Expansion**: Cloud SQL storage increases are applied in-place dynamically. Disk size can only be scaled up (never down).
* **Cloud Run Sizing**: Updating CPU or memory limits triggers a seamless rolling update with zero downtime.

---

## 2. In-Place Tier & Sizing Upgrade Process

All infrastructure modifications **must** be performed via Terraform git ops workflows (`develop` $\rightarrow$ `main`).

### Step 1: Modify Infrastructure Configuration
Edit the sizing parameters in the appropriate environment stack call:

* **Dev Environment**: Modify [environments/dev/main.tf](file:///Users/vijayanathanelangovan/dev/permica-ril-infra/environments/dev/main.tf)
* **Prod Environment**: Modify [environments/prod/main.tf](file:///Users/vijayanathanelangovan/dev/permica-ril-infra/environments/prod/main.tf)

Example update for Cloud SQL tier:
```hcl
module "stack" {
  source = "../../modules/stack"

  # ... other variables ...
  
  # Upgraded Tier
  db_tier = "db-custom-4-15360" # 4 vCPUs, 15 GB RAM
}
```

### Step 2: Open Pull Request & Inspect Plan
1. Open a PR targeting `develop` (for dev) or `main` (for prod).
2. The GitHub Actions workflow (`terraform-dev.yml` or `terraform-prod.yml`) will run `terraform plan`.
3. Check the PR run summary to verify that Terraform shows an **in-place update (`~`)** and **NOT a replacement (`-/+`)**.

> [!IMPORTANT]
> If `terraform plan` indicates a resource will be destroyed or replaced (`-/+`), **STOP** immediately and inspect why the resource name or immutable property changed.

### Step 3: Merge & Apply
* **Dev**: Merging to `develop` applies the upgrade to the dev environment automatically.
* **Prod**: Merging to `main` triggers a plan; a human reviewer must approve the `production` GitHub Environment deployment to apply.

---

## 3. Downtime & High Availability (HA) Expectations

| Component | Operation | Impact / Downtime | Notes |
| :--- | :--- | :--- | :--- |
| **Cloud SQL** | Tier Change (RAM/CPU) | ~1 to 3 minutes restart | Failover occurs if High Availability (HA) is enabled |
| **Cloud SQL** | Disk Expansion | **Zero downtime** | Dynamic resize on active instance |
| **Cloud Run** | CPU / Memory / Instance limits | **Zero downtime** | Rolling revision replacement |
| **Bigtable** | Node Count / Sizing | **Zero downtime** | Dynamic node scaling |

---

## 4. Production Best Practices & Safeguards

Before applying major database tier updates in production:

1. **Manual On-Demand Backup**:
   Run an on-demand Cloud SQL backup via GCP CLI before applying infrastructure changes:
   ```bash
   gcloud sql backups create --instance=<PROD-SQL-INSTANCE-NAME> --project=<PROD-PROJECT-ID>
   ```

2. **Verify Deletion Protection**:
   Ensure `deletion_protection = true` is set in production ([environments/prod/main.tf](file:///Users/vijayanathanelangovan/dev/permica-ril-infra/environments/prod/main.tf)).

3. **High Availability (HA)**:
   Ensure `availability_type = "REGIONAL"` is set for production Cloud SQL so failover is seamless during tier maintenance.
