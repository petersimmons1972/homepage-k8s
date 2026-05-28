# Archived Homepage Configurations

**Archived Date:** 2026-01-02

## Purpose

These configuration files are historical backups from Homepage deployments that included references to:
- **Hoarder** - Bookmark management service (no longer deployed)
- **Karakeep** - Note-taking service (no longer used)

## Why Archived

As of January 2, 2026, these services have been removed from the homelab infrastructure. These backup files are preserved for historical reference but should NOT be used for restoration without first removing the outdated service references.

## Files in This Archive

- `configmap-backup-20251202.yaml` - Backup from December 2, 2025
- `configmap-backup-20251220-222524.yaml` - Backup from December 20, 2025
- `configmap-backup-20251222-221814.yaml` - Backup from December 22, 2025 (22:18)
- `configmap-backup-20251222-223059.yaml` - Backup from December 22, 2025 (22:30)
- `configmap-backup-20251222-223444.yaml` - Backup from December 22, 2025 (22:34)
- `configmap-backup-predashboards.yaml` - Pre-dashboards backup from December 27, 2025

## Current Working Configuration

For the current, clean configuration without Hoarder/Karakeep references, use:
- `/home/psimmons/projects/kubernetes/homepage/configmap-updated.yaml`

See also:
- `/home/psimmons/projects/kubernetes/homepage/GOLDEN-CONFIG-BASELINE.md`

## If You Need to Reference These

If you need to look at these configurations:
1. They contain outdated service references that have been removed
2. Remove references to Hoarder and Karakeep before using
3. Consider using the current working configuration instead

## Cleanup Actions Performed

On 2026-01-02, the following cleanup was performed across the codebase:
- Removed Hoarder service references from all active configuration files
- Removed Karakeep bookmark references from all active configuration files
- Updated documentation to reflect service removals
- Archived old backup files containing these references

For details, see the cleanup summary in the main projects directory.
