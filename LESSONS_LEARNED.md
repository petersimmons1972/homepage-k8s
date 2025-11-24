# Homepage Lessons Learned - Avoiding Recurring API Errors

## Problem Pattern

Homepage has had recurring API errors across multiple sessions, requiring significant debugging time each time. This document captures the root causes and prevention strategies.

---

## Core Issues Identified

### 1. Using `:latest` Tag Instead of Pinned Versions

**Why This Causes Problems:**
- Homepage `:latest` gets auto-updated to new versions with breaking changes
- New versions often have bugs in Kubernetes integration
- Version changes happen silently without our knowledge
- Different versions have different configuration requirements

**Examples:**
- v1.7.0 (latest at time) introduced requirement for `proxmox.yaml` file
- v1.7.0 had buggy ingress API client causing `NaN undefined` errors
- Version changes broke previously working configurations

**Prevention:**
```yaml
# BAD - Never use this
image: ghcr.io/gethomepage/homepage:latest

# GOOD - Always pin to tested version
image: ghcr.io/gethomepage/homepage:v0.9.5
```

**Lesson**: ALWAYS pin container images to specific tested versions. Never use `:latest` in production.

---

### 2. Kubernetes Auto-Discovery Mode Enabled by Default

**Why This Causes Problems:**
- `mode: cluster` in `kubernetes.yaml` enables automatic service discovery
- Homepage tries to query Kubernetes APIs constantly
- If RBAC permissions are incomplete, generates errors
- If Kubernetes API responses change format, causes parsing errors
- Creates noise in logs making real issues hard to spot

**The Hidden Default:**
```yaml
# Even if you don't specify a kubernetes widget,
# this still runs background queries
kubernetes.yaml: |
  mode: cluster  # ← This enables auto-discovery
```

**What Happens:**
1. Homepage scans all namespaces for services
2. Tries to list all ingresses every 3 seconds
3. Attempts to auto-populate service widgets
4. If any API call fails → continuous error spam

**Prevention:**
```yaml
# Explicitly disable if not using Kubernetes integration
kubernetes.yaml: |
  mode: disabled
```

**Lesson**: Don't rely on defaults. Explicitly configure what you want, especially for features that poll APIs.

---

### 3. Widget Configuration Inconsistency

**Why This Causes Problems:**
- Widgets can be defined in multiple places:
  - `widgets.yaml` (global widgets)
  - `services.yaml` (per-service widgets)
  - Auto-discovered via kubernetes mode
- Having widgets without proper backend config causes errors
- Proxmox widget needs `proxmox.yaml` file
- Pi-hole widget needs correct API keys

**Example of Problem:**
```yaml
services.yaml:
  - Proxmox:
      widget:
        type: proxmox
        url: https://pve.petersimmons.com:8006
        # Widget defined but no proxmox.yaml file mounted!
```

**Prevention Checklist:**
1. If you define a widget, ensure its config file exists
2. Mount ALL required config files in deployment
3. Test widget connectivity before deploying
4. Remove widgets that aren't critical

**Required Files by Widget Type:**
- `proxmox` widget → needs `proxmox.yaml`
- `docker` widget → needs `docker.yaml`
- `kubernetes` widget → needs proper RBAC + `kubernetes.yaml`
- `pihole` widget → needs API key in widget config

**Lesson**: Widget configuration has dependencies. Document and validate all requirements before enabling.

---

### 4. Insufficient Error Analysis Before Making Changes

**Why This Causes Problems:**
- Made configuration changes without fully understanding error patterns
- Fixed symptoms instead of root causes
- Applied partial fixes that didn't address underlying issues
- Restarted pods hoping errors would go away

**What Happened This Session:**
1. Saw API errors → Fixed icons (unrelated)
2. Saw more API errors → Changed image version (partial fix)
3. Still had errors → Disabled node metrics (incomplete)
4. FINALLY → Disabled kubernetes mode (actual root cause)

**Better Approach:**
```bash
# STEP 1: Collect error patterns
kubectl logs -n default deployment/homepage --tail=200 | \
  grep error | sort | uniq -c | sort -rn

# STEP 2: Identify unique error types
# - What's the error message?
# - Which component is generating it?
# - How frequently does it occur?

# STEP 3: Find root cause
# - Is it configuration?
# - Is it a bug in the version?
# - Is it a missing dependency?

# STEP 4: Fix root cause, not symptoms
# - Make targeted fix
# - Verify with clean logs
# - Document what was fixed and why
```

**Lesson**: Always analyze error patterns systematically BEFORE making changes. Fix root causes, not symptoms.

---

### 5. Not Preserving Known-Good Configurations

**Why This Causes Problems:**
- No baseline "working configuration" to revert to
- Configuration drift happens gradually
- Hard to identify what changed when errors appear
- No version control for config changes

**Example:**
- Homepage was working perfectly 2 days ago
- Applied security hardening
- Now has errors
- Can't easily revert to working state

**Prevention:**
```bash
# Before ANY changes to Homepage
cd /home/psimmons/projects/kubernetes/homepage
cp configmap-updated.yaml "configmap-backup-$(date +%Y%m%d-%H%M%S).yaml"

# Tag working configurations in git
git tag homepage-working-2025-11-24
git push --tags

# Document what's working
echo "Status: All services loading, zero errors" > STATUS.txt
echo "Version: v0.9.5" >> STATUS.txt
echo "Date: $(date)" >> STATUS.txt
```

**Lesson**: Always backup working configurations before changes. Use git tags for known-good states.

---

## Prevention Strategy: The Homepage Checklist

### Before Deploying/Updating Homepage

- [ ] Image version is pinned (not `:latest`)
- [ ] Check release notes for breaking changes
- [ ] All required config files listed in deployment volumeMounts
- [ ] `kubernetes.yaml` mode explicitly set (`disabled` if not using K8s features)
- [ ] Widget dependencies validated (API keys, URLs, config files)
- [ ] RBAC permissions match enabled features
- [ ] Backup current working configuration
- [ ] Test in non-production namespace first

### After Deploying Homepage

- [ ] Pod starts successfully
- [ ] Check logs for errors: `kubectl logs -n default deployment/homepage --tail=100 | grep error`
- [ ] Verify services load: `curl -k https://homepage.petersimmons.com/api/services | jq`
- [ ] Test actual page in browser (hard refresh)
- [ ] Monitor logs for 5 minutes for recurring errors
- [ ] Document working configuration

### When Errors Appear

1. **Collect Data First**
   ```bash
   kubectl logs -n default deployment/homepage --tail=200 | grep error | sort | uniq -c | sort -rn > /tmp/homepage-errors.txt
   ```

2. **Analyze Pattern**
   - What's the error message?
   - Which component? (kubernetes-widget, httpProxy, service-helpers)
   - How often? (every 3s = polling, occasional = transient)

3. **Identify Root Cause**
   - Configuration issue?
   - Version bug?
   - Missing dependency?
   - Network/connectivity problem?

4. **Fix Root Cause**
   - Make targeted change
   - Document why
   - Verify logs are clean

5. **Prevent Recurrence**
   - Add to this document
   - Update checklist
   - Consider automation

---

## Configuration Rules for Homepage

### Rule 1: Explicit Is Better Than Implicit
```yaml
# DON'T rely on defaults
kubernetes.yaml: ""

# DO explicitly configure
kubernetes.yaml: |
  mode: disabled
```

### Rule 2: Pin Everything
```yaml
# DON'T use floating tags
image: ghcr.io/gethomepage/homepage:latest

# DO pin versions
image: ghcr.io/gethomepage/homepage:v0.9.5
imagePullPolicy: IfNotPresent
```

### Rule 3: Match Config to Features
```yaml
# If you enable a widget
services.yaml:
  - Proxmox:
      widget:
        type: proxmox

# You MUST have its config
deployment.yaml:
  volumeMounts:
    - mountPath: /app/config/proxmox.yaml
      name: homepage-config
      subPath: proxmox.yaml

configmap.yaml:
  proxmox.yaml: |
    url: https://pve.petersimmons.com:8006
    ...
```

### Rule 4: Validate Before Deploy
```bash
# Test configuration syntax
kubectl apply --dry-run=client -f configmap-updated.yaml

# Verify all referenced files exist
kubectl get configmap homepage -n default -o yaml | grep -E "\.yaml:" 

# Check for missing mounts
kubectl get deployment homepage -n default -o yaml | grep -A20 volumeMounts
```

### Rule 5: Monitor After Changes
```bash
# Watch logs for 5 minutes after any change
kubectl logs -n default deployment/homepage -f | grep --line-buffered error

# Zero errors = success
# Any errors = investigate before moving on
```

---

## Common Homepage Errors and Fixes

### Error: `<kubernetes-widget> Error getting ingresses: NaN undefined undefined`
**Cause**: Kubernetes mode enabled with buggy API client  
**Fix**: Set `kubernetes.yaml` to `mode: disabled`  
**Prevention**: Only enable kubernetes mode if you actually need auto-discovery

### Error: `Failed to initialize required config: /app/config/proxmox.yaml`
**Cause**: Proxmox widget defined but config file not mounted  
**Fix**: Add proxmox.yaml to configmap and deployment volumeMounts  
**Prevention**: Match widget configs to mounted files

### Error: `ECONNREFUSED` to Proxmox/Service
**Cause**: Service unreachable from pod's network  
**Fix**: Verify service is accessible, check DNS, remove widget if not needed  
**Prevention**: Test connectivity before adding widgets

### Error: `Cannot read properties of null (reading 'items')`
**Cause**: API response format doesn't match expected structure  
**Fix**: Usually a version bug - downgrade to stable version  
**Prevention**: Pin versions, test before updating

### Error: `Failed to discover services, check kubernetes.yaml`
**Cause**: RBAC permissions insufficient or kubernetes mode misconfigured  
**Fix**: Disable kubernetes mode or fix RBAC  
**Prevention**: Explicitly configure mode, validate RBAC matches features

---

## Automation Opportunities

### 1. Health Check Script
```bash
#!/bin/bash
# /home/psimmons/projects/kubernetes/homepage/health-check.sh

echo "Checking Homepage health..."

# Check pod is running
POD_STATUS=$(kubectl get pods -n default -l app=homepage -o jsonpath='{.items[0].status.phase}')
if [ "$POD_STATUS" != "Running" ]; then
    echo "❌ Pod not running: $POD_STATUS"
    exit 1
fi

# Check for errors in last 2 minutes
ERROR_COUNT=$(kubectl logs -n default -l app=homepage --since=2m 2>&1 | grep -c error)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "❌ Found $ERROR_COUNT errors in logs"
    kubectl logs -n default -l app=homepage --since=2m 2>&1 | grep error | head -10
    exit 1
fi

# Check API responds
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" https://homepage.petersimmons.com)
if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ HTTP error: $HTTP_CODE"
    exit 1
fi

echo "✅ Homepage is healthy"
exit 0
```

### 2. Configuration Validator
```bash
#!/bin/bash
# Validate Homepage configuration before applying

echo "Validating Homepage configuration..."

# Check image is pinned
if grep -q "image:.*:latest" deployment.yaml; then
    echo "❌ Using :latest tag - pin to specific version"
    exit 1
fi

# Check all widget configs are mounted
WIDGETS=$(grep -A2 "widget:" configmap-updated.yaml | grep "type:" | awk '{print $2}')
for widget in $WIDGETS; do
    if ! grep -q "${widget}.yaml" deployment.yaml; then
        echo "❌ Widget $widget defined but config not mounted"
        exit 1
    fi
done

echo "✅ Configuration valid"
```

### 3. Deployment Procedure
```bash
#!/bin/bash
# Safe Homepage deployment with validation

set -e

echo "=== Homepage Deployment ==="

# Backup current config
kubectl get configmap homepage -n default -o yaml > "backup-$(date +%Y%m%d-%H%M%S).yaml"

# Validate new config
./validate-config.sh

# Apply changes
kubectl apply -f configmap-updated.yaml
kubectl apply -f deployment.yaml

# Wait for rollout
kubectl rollout status deployment/homepage -n default --timeout=60s

# Health check
sleep 20
./health-check.sh

echo "✅ Deployment successful"
```

---

## Key Takeaways

### The Real Problems Were:

1. **Not pinning versions** → Silent breaking changes
2. **Kubernetes mode enabled** → Continuous API polling with buggy client
3. **Missing widget dependencies** → Config files not mounted
4. **Fixing symptoms not causes** → Icons, versions, but not root issue
5. **No systematic debugging** → Trial and error instead of analysis

### The Solution Is:

1. **Always pin versions** → Control when updates happen
2. **Explicitly disable unused features** → Don't rely on defaults
3. **Validate widget dependencies** → Match config to features
4. **Analyze before acting** → Understand errors before fixing
5. **Automate validation** → Catch issues before deployment

### Moving Forward:

1. ✅ Homepage now at `v0.9.5` (pinned)
2. ✅ Kubernetes mode disabled
3. ✅ Only essential widgets enabled
4. ✅ All required configs mounted
5. ✅ Zero API errors confirmed
6. ✅ Health check automation created
7. ✅ This lessons document created

**Never use `:latest` tags in production. Always understand errors before attempting fixes.**

---

## Quick Reference

**Current Working Configuration:**
- Image: `ghcr.io/gethomepage/homepage:v0.9.5`
- Kubernetes mode: `disabled`
- Widgets: resources, search (no kubernetes, no problematic service widgets)
- Services: 30 configured across 5 categories
- Status: Zero errors

**Files:**
- `/home/psimmons/projects/kubernetes/homepage/deployment.yaml`
- `/home/psimmons/projects/kubernetes/homepage/configmap-updated.yaml`
- `/home/psimmons/projects/kubernetes/homepage/LESSONS_LEARNED.md` (this file)

**Validation Commands:**
```bash
# Check for errors
kubectl logs -n default deployment/homepage --tail=100 | grep error

# Should return: (empty - no errors)

# Verify services loading
curl -k -s https://homepage.petersimmons.com/api/services | jq '.[].name'

# Should return: "Work", "Homelab Services", etc.
```

---

**Document Created:** November 24, 2025  
**Author:** Lessons learned from recurring Homepage API error debugging  
**Purpose:** Prevent future Homepage issues by understanding root causes
