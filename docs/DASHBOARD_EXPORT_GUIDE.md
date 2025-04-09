# Grafana Dashboard Backup Guide (Automated via GitHub Actions)

This guide outlines how we back up Grafana dashboards automatically using a GitHub Actions workflow.

## Overview

Grafana dashboards are now backed up **daily** and whenever the workflow is triggered manually. The
workflow is configured to:

1. Sync dashboards from the live Grafana instance to the repo using the
   [`grafana-sync-action`][grana-sync-action].
2. Create a pull request containing the updated dashboards.
3. Keep the PR in **draft** mode to support a quality control workflow that triggers only when the
   PR is marked "Ready for review."

## Why Draft PRs?

We use the `draft: always-true` option to intentionally keep the pull request in **draft mode**.
This is a workaround to ensure that our quality workflow (e.g., linting, validation) runs only when
someone explicitly clicks **"Ready for review"**.

This approach is necessary because GitHub does **not** re-trigger `pull_request` workflows
automatically when a PR is updated — unless using a **Personal Access Token (PAT)**, which we're
avoiding for now.

👉 See the workaround explanation here:
[Triggering further workflow runs – peter-evans/create-pull-request][peter-evans-workaround]

## Manual Backup

To trigger the backup manually:

1. Go to [**Actions -> Grafana Dashboard Backup**][backup-workflow] from the workflows list.
2. Click **Run workflow** on the `main` branch.

[peter-evans-workaround]: https://github.com/peter-evans/create-pull-request/blob/main/docs/concepts-guidelines.md#triggering-further-workflow-runs
[backup-workflow]: https://github.com/SRGSSR/pillarbox-monitoring-infra/actions/workflows/dashboard-backup.yml
[grana-sync-action]: https://github.com/srgssr/grafana-sync-action
