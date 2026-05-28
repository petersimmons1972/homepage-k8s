# Homepage Testing Procedures

## CRITICAL: HTTP 200 Does NOT Mean Homepage Is Working

**Homepage is unique among our Kubernetes applications.** Unlike other services where an HTTP 200 status code indicates success, Homepage can return HTTP 200 while being completely broken with API errors on the page itself.

**This document is MANDATORY for all Homepage changes.**

---

## Why Homepage Requires Special Testing

### The Problem

Homepage has a unique architecture that makes standard Kubernetes health checks insufficient:

1. **The pod can be Running** → ✅ Kubernetes shows healthy
2. **The service can return HTTP 200** → ✅ curl shows success
3. **But the page shows "API Error" in every widget** → ❌ Actually broken

### Real Example

```bash
# Standard check - looks good!
$ curl -s -o /dev/null -w "%{http_code}" https://homepage.petersimmons.com
200

# Download actual HTML - reveals the truth!
$ curl -s https://homepage.petersimmons.com | grep -i "api error"
<div class="error">API Error</div>
<div class="error">API Error</div>
<div class="error">API Error</div>
```

**The page returned HTTP 200 but is completely broken.**

---

## Mandatory Testing Checklist

**Before ANY Homepage change can be considered complete, ALL of these tests MUST pass:**

### Phase 1: Pre-Deployment Validation

- [ ] **Configuration syntax validated**
  ```bash
  kubectl apply --dry-run=client -f configmap-updated.yaml
  ```

- [ ] **Widget dependencies verified** (if widgets are configured)
  - Every widget has its required config file mounted
  - API endpoints are reachable
  - Credentials/API keys are valid

- [ ] **Image version is pinned** (never use `:latest`)
  ```bash
  grep "image:" deployment.yaml | grep -v "latest"
  ```

- [ ] **Backup created**
  ```bash
  kubectl get configmap homepage -n default -o yaml > backup-$(date +%Y%m%d-%H%M%S).yaml
  ```

### Phase 2: Deployment Verification

- [ ] **Pod starts successfully**
  ```bash
  kubectl get pods -l app.kubernetes.io/name=homepage
  # Must show: Running and 1/1 Ready
  ```

- [ ] **No errors in startup logs**
  ```bash
  kubectl logs -n default deployment/homepage --tail=50 | grep -i error
  # Must return: (empty)
  ```

### Phase 3: Functional Testing (CRITICAL)

**This is where most people stop - but this is where Homepage testing BEGINS.**

- [ ] **HTTP status code check** (necessary but NOT sufficient)
  ```bash
  curl -s -o /dev/null -w "%{http_code}" https://homepage.petersimmons.com
  # Must return: 200
  ```

- [ ] **Download and inspect actual HTML content**
  ```bash
  curl -s https://homepage.petersimmons.com > /tmp/homepage-test.html
  ```

- [ ] **Verify NO API errors in HTML**
  ```bash
  grep -i "api error" /tmp/homepage-test.html
  # Must return: (empty - no matches)
  ```

- [ ] **Verify NO "Something went wrong" errors**
  ```bash
  grep -i "something went wrong" /tmp/homepage-test.html
  # Must return: (empty - no matches)
  ```

- [ ] **Verify widgets are rendering data** (not just loading)
  ```bash
  # Check that actual service names appear in HTML
  grep -E "(Proxmox|Searxng|n8n|Linkwarden)" /tmp/homepage-test.html
  # Must find: your configured services
  ```

- [ ] **Visual browser verification**
  - Open https://homepage.petersimmons.com in browser
  - Hard refresh (Ctrl+Shift+R)
  - Verify widgets show data (not "API Error")
  - Verify all configured services appear
  - Verify search bar works
  - Check browser console for JavaScript errors

- [ ] **Widget functionality verification**
  - Check Proxmox widget shows actual stats (CPU, memory, storage)
  - Check Pihole widgets show query counts and blocking stats
  - Verify resource widgets display real data (not dashes/zeros)
  - Confirm widgets are NOT showing static/placeholder data

- [ ] **Favicon verification**
  - Verify favicons load correctly for all services
  - Common problem services: LinkedIn, Perplexity, Linkerd, Dashlane
  - Check browser network tab for favicon 404 errors
  - Note: Some favicons may need manual icon specification instead of automatic fetching

### Phase 4: Stability Testing

- [ ] **Monitor logs for 5 minutes**
  ```bash
  kubectl logs -n default deployment/homepage -f | grep --line-buffered -i error
  # Must show: no recurring errors
  ```

- [ ] **Run automated health check**
  ```bash
  /home/psimmons/projects/kubernetes/homepage/homepage-health-monitor.sh
  # Must show: ✅ All health checks passed!
  ```

- [ ] **Verify internal cluster connectivity**
  ```bash
  kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never -- \
    curl -v http://homepage-service.default.svc.cluster.local:3000
  # Must return: HTTP 200 with HTML content
  ```

---

## Automated Test Script

Use this script for consistent testing after every Homepage change:

```bash
#!/bin/bash
# /home/psimmons/projects/kubernetes/homepage/test-homepage.sh

set -e

echo "========================================="
echo "Homepage Comprehensive Test Suite"
echo "========================================="
echo ""

# Test 1: Pod Health
echo "[1/8] Checking pod status..."
POD_STATUS=$(kubectl get pods -n default -l app.kubernetes.io/name=homepage -o jsonpath='{.items[0].status.phase}')
if [ "$POD_STATUS" != "Running" ]; then
    echo "❌ FAIL: Pod status is $POD_STATUS"
    exit 1
fi
echo "✅ PASS: Pod is Running"
echo ""

# Test 2: No Startup Errors
echo "[2/8] Checking for startup errors..."
ERROR_COUNT=$(kubectl logs -n default deployment/homepage --tail=50 | grep -ic error || true)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "❌ FAIL: Found $ERROR_COUNT errors in startup logs"
    kubectl logs -n default deployment/homepage --tail=50 | grep -i error
    exit 1
fi
echo "✅ PASS: No startup errors"
echo ""

# Test 3: HTTP Status Code
echo "[3/8] Checking HTTP status code..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" https://homepage.petersimmons.com)
if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ FAIL: HTTP code is $HTTP_CODE"
    exit 1
fi
echo "✅ PASS: HTTP 200 received"
echo ""

# Test 4: Download HTML Content
echo "[4/8] Downloading HTML content..."
curl -k -s https://homepage.petersimmons.com > /tmp/homepage-content.html
HTML_SIZE=$(wc -c < /tmp/homepage-content.html)
if [ "$HTML_SIZE" -lt 1000 ]; then
    echo "❌ FAIL: HTML content too small ($HTML_SIZE bytes)"
    exit 1
fi
echo "✅ PASS: HTML downloaded ($HTML_SIZE bytes)"
echo ""

# Test 5: Check for API Errors (CRITICAL)
echo "[5/8] Checking for API errors in HTML..."
API_ERROR_COUNT=$(grep -ic "api error" /tmp/homepage-content.html || true)
if [ "$API_ERROR_COUNT" -gt 0 ]; then
    echo "❌ FAIL: Found $API_ERROR_COUNT 'API Error' messages in HTML"
    echo "Homepage returned HTTP 200 but widgets are broken!"
    grep -i "api error" /tmp/homepage-content.html | head -5
    exit 1
fi
echo "✅ PASS: No API errors in HTML content"
echo ""

# Test 5b: Check for "Something went wrong" Errors
echo "[5b/8] Checking for 'Something went wrong' errors..."
SOMETHING_WRONG_COUNT=$(grep -ic "something went wrong" /tmp/homepage-content.html || true)
if [ "$SOMETHING_WRONG_COUNT" -gt 0 ]; then
    echo "❌ FAIL: Found $SOMETHING_WRONG_COUNT 'Something went wrong' error messages"
    grep -i "something went wrong" /tmp/homepage-content.html | head -5
    exit 1
fi
echo "✅ PASS: No 'Something went wrong' errors"
echo ""

# Test 6: Verify Widget Rendering
echo "[6/8] Checking if widgets are rendering..."
SERVICE_COUNT=$(grep -c "service-card" /tmp/homepage-content.html || true)
if [ "$SERVICE_COUNT" -lt 5 ]; then
    echo "⚠️  WARNING: Only found $SERVICE_COUNT service cards (expected more)"
fi
echo "✅ PASS: Found $SERVICE_COUNT service cards"
echo ""

# Test 7: Internal Connectivity
echo "[7/8] Testing internal cluster connectivity..."
INTERNAL_TEST=$(kubectl run test-curl-$RANDOM --image=curlimages/curl --rm -i --restart=Never -- \
  curl -s -o /dev/null -w "%{http_code}" http://homepage-service.default.svc.cluster.local:3000 2>/dev/null)
if [ "$INTERNAL_TEST" != "200" ]; then
    echo "❌ FAIL: Internal connectivity test returned $INTERNAL_TEST"
    exit 1
fi
echo "✅ PASS: Internal connectivity works"
echo ""

# Test 8: Recent Log Errors
echo "[8/8] Checking for recent errors in logs..."
RECENT_ERRORS=$(kubectl logs -n default deployment/homepage --since=2m 2>&1 | grep -ic error || true)
if [ "$RECENT_ERRORS" -gt 0 ]; then
    echo "❌ FAIL: Found $RECENT_ERRORS errors in recent logs"
    kubectl logs -n default deployment/homepage --since=2m 2>&1 | grep -i error | head -10
    exit 1
fi
echo "✅ PASS: No recent errors in logs"
echo ""

echo "========================================="
echo "✅ ALL TESTS PASSED"
echo "Homepage is functioning correctly"
echo "========================================="

# Save test result with timestamp
echo "Test passed at $(date)" >> /home/psimmons/projects/kubernetes/homepage/test-results.log
```

**Make the script executable:**
```bash
chmod +x /home/psimmons/projects/kubernetes/homepage/test-homepage.sh
```

---

## Common Failure Modes

### Failure Mode 1: HTTP 200 + API Errors

**Symptoms:**
- `curl` shows HTTP 200
- Pod is Running
- But page shows "API Error" everywhere

**Root Causes:**
- Widget misconfiguration
- Backend service unavailable
- Network policy blocking widget API calls
- Kubernetes auto-discovery enabled with insufficient RBAC

**Detection:**
```bash
curl -s https://homepage.petersimmons.com | grep -i "api error"
```

**Fix:**
- Check widget configurations in ConfigMap
- Verify backend services are accessible
- Review network policies (especially label selectors)
- Disable kubernetes mode if not needed

### Failure Mode 2: Configuration Syntax Error

**Symptoms:**
- Pod CrashLoopBackOff
- Logs show YAML parsing errors

**Root Causes:**
- Invalid YAML syntax in ConfigMap
- Missing required fields
- Incorrect indentation

**Detection:**
```bash
kubectl apply --dry-run=client -f configmap-updated.yaml
kubectl logs -n default deployment/homepage --tail=20
```

**Fix:**
- Validate YAML syntax
- Compare to working backup
- Check Homepage documentation for required fields

### Failure Mode 3: Network Policy Blocking Traffic

**Symptoms:**
- HTTP 502 Bad Gateway
- Pod running but unreachable
- Traefik can't connect to service

**Root Causes:**
- Network policy label selectors don't match pod labels
- Homepage uses `app.kubernetes.io/name=homepage` (not `app=homepage`)

**Detection:**
```bash
# Check network policy selectors
kubectl get networkpolicy -o yaml | grep -A2 matchLabels

# Check actual pod labels
kubectl get pods -l app.kubernetes.io/name=homepage --show-labels
```

**Fix:**
- Update network policies to use correct label selectors
- See: `/home/psimmons/projects/homepage-network-policies.yaml`

---

### Failure Mode 4: Widget Dynamic Functionality Lost

**Symptoms:**
- Widgets appear on page but show no data
- Proxmox widget doesn't show CPU/memory/storage stats
- Pihole widgets don't show query counts or blocking stats
- Widgets show static/placeholder data instead of live stats

**Root Causes:**
- Widget configuration removed or corrupted in ConfigMap
- Backend API credentials missing or invalid
- Network policies blocking widget API calls
- Service configuration changed breaking widget integration

**Detection:**
```bash
# Check widget configuration in ConfigMap
kubectl get configmap homepage -o yaml | grep -A 20 "widgets.yaml:"

# Check for widget-specific errors in logs
kubectl logs -n default deployment/homepage | grep -i widget

# Test widget API endpoints
curl -k https://homepage.petersimmons.com/api/widgets
```

**Fix:**
- Restore widget configuration from backup
- Verify widget backend services are accessible
- Check network policies allow widget API calls
- Validate API credentials in widget configs

**Prevention:**
- Always test widget functionality after config changes
- Keep backups of known-working widget configurations
- Document which widgets require special configuration

---

### Failure Mode 5: Favicon Loading Issues

**Symptoms:**
- Services appear but show broken/incorrect favicons
- Common problem services: LinkedIn, Perplexity, Linkerd, Dashlane
- Browser shows generic/default icons instead of service logos

**Root Causes:**
- Automatic favicon fetching fails for some domains
- Favicon URL returns 404 or CORS error
- Service uses non-standard favicon location
- Homepage cannot access favicon due to CSP/CORS

**Detection:**
```bash
# Check browser network tab for favicon 404 errors
# Visual inspection of Homepage in browser

# Test favicon URLs directly
curl -I https://linkedin.com/favicon.ico
curl -I https://perplexity.ai/favicon.ico
```

**Fix:**
- Use explicit icon URLs instead of automatic fetching
- Use Dashboard Icons or icon libraries (mdi, si, etc.)
- Specify full icon URLs in service config
- For persistent issues, use base64-encoded icons

**Example Fix:**
```yaml
# Instead of relying on automatic favicon
- LinkedIn:
    href: https://linkedin.com/
    icon: https://linkedin.com/favicon.ico  # May fail

# Use icon library instead
- LinkedIn:
    href: https://linkedin.com/
    icon: mdi-linkedin  # More reliable
```

**Prevention:**
- Always verify favicons load after adding/changing services
- Prefer icon libraries over automatic favicon fetching
- Test in browser network tab for favicon errors
- Document known problematic services

---

## Integration with CI/CD

### Pre-Commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

if git diff --cached --name-only | grep -q "homepage/configmap"; then
    echo "Homepage config changed - validating..."
    kubectl apply --dry-run=client -f kubernetes/homepage/configmap-updated.yaml
    if [ $? -ne 0 ]; then
        echo "❌ Invalid Homepage configuration"
        exit 1
    fi
fi
```

### Post-Deployment Verification

Add to your deployment scripts:

```bash
# After kubectl apply
echo "Waiting for Homepage to stabilize..."
sleep 30

# Run comprehensive tests
./test-homepage.sh

if [ $? -ne 0 ]; then
    echo "❌ Homepage tests failed - consider rollback"
    exit 1
fi
```

---

## Quick Reference

### Minimum Viable Test

**If you only have time for ONE test, do this:**

```bash
curl -s https://homepage.petersimmons.com | grep -i "api error"
```

**Expected result:** No output (no API errors found)

**If you see API errors:** Homepage is broken despite HTTP 200

### Full Test Command

```bash
/home/psimmons/projects/kubernetes/homepage/test-homepage.sh
```

### Emergency Rollback

```bash
# Find latest backup
ls -lt /home/psimmons/projects/kubernetes/homepage/backup-*.yaml | head -1

# Restore
kubectl apply -f backup-YYYYMMDD-HHMMSS.yaml

# Restart deployment
kubectl rollout restart deployment/homepage -n default

# Wait for rollout
kubectl rollout status deployment/homepage -n default

# Verify
./test-homepage.sh
```

---

## Documentation and Learning

### After Every Homepage Issue

1. **Document what went wrong**
   - Add to LESSONS_LEARNED.md
   - Note what didn't work
   - Explain root cause

2. **Update this testing guide**
   - Add new failure mode if discovered
   - Improve detection methods
   - Add preventive measures

3. **Update CLAUDE.md**
   - Ensure AI assistants learn from this
   - Add to troubleshooting quick reference
   - Update Homepage-specific warnings

### Test Result Logging

Keep a history of test results:

```bash
# After each successful test
echo "$(date): Test passed - Config hash: $(md5sum configmap-updated.yaml | awk '{print $1}')" \
  >> /home/psimmons/projects/kubernetes/homepage/test-results.log
```

---

## Remember

**✅ HTTP 200 = Server responded**
**✅ HTML content with no "API Error" = Homepage actually works**

**Never assume Homepage is working based on HTTP status code alone.**

**Always download and inspect the actual HTML content.**

**When in doubt, run the full test suite.**

---

## Related Documentation

- `/home/psimmons/projects/kubernetes/homepage/MONITORING.md` - Continuous health monitoring
- `/home/psimmons/projects/kubernetes/homepage/LESSONS_LEARNED.md` - Historical issues and root causes
- `/home/psimmons/CLAUDE.md` - Project instructions including Homepage troubleshooting
- `/home/psimmons/projects/kubernetes-cluster-documentation/applications/homepage.md` - Architecture docs

---

**Document Created:** 2025-12-20
**Purpose:** Mandatory testing procedures for Homepage changes
**Key Lesson:** HTTP 200 ≠ Homepage is working - always verify HTML content
