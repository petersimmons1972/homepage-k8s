# Homepage Health Monitoring

This document describes the health monitoring solution for the Homepage Kubernetes application.

## Background

Homepage is identified as "the single most problematic app" in the cluster, with recurring failures. This monitoring system was created to proactively detect and alert on Homepage issues.

## Health Monitor Script

Location: `/home/psimmons/projects/kubernetes/homepage/homepage-health-monitor.sh`

### Features

The script performs the following checks:

1. **Pod Status** - Verifies Homepage pods are running
2. **Label Consistency** - Ensures network policies use correct labels
3. **Service Endpoints** - Confirms service has active endpoints
4. **Network Policies** - Validates network policy configuration
5. **Pod Logs** - Scans for errors in recent logs
6. **Internal Connectivity** - Tests access from within the cluster
7. **External URL** - Validates HTTPS endpoint returns HTTP 200
8. **API Errors** - Checks HTML content for API error messages

### Usage

```bash
# Run single health check
./homepage-health-monitor.sh

# Run continuous monitoring (every 60 seconds)
./homepage-health-monitor.sh --continuous

# Run with custom interval
./homepage-health-monitor.sh --continuous --interval 300

# Enable Slack alerts
./homepage-health-monitor.sh --continuous --slack-webhook https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Log to file
./homepage-health-monitor.sh --continuous --log /var/log/homepage-health.log

# Combined options
./homepage-health-monitor.sh --continuous --interval 120 --slack-webhook $SLACK_URL --log /var/log/homepage.log
```

### Deployment Options

#### Option 1: Kubernetes CronJob

Create a CronJob to run health checks periodically:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: homepage-health-check
  namespace: default
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: homepage-monitor
          containers:
          - name: health-check
            image: bitnami/kubectl:latest
            env:
            - name: SLACK_WEBHOOK
              valueFrom:
                secretKeyRef:
                  name: homepage-monitor-secrets
                  key: slack-webhook
            command:
            - /bin/bash
            - -c
            - |
              # Install curl
              apt-get update && apt-get install -y curl
              # Download and run health check script
              curl -o /tmp/health-check.sh https://raw.githubusercontent.com/YOUR-REPO/homepage-health-monitor.sh
              chmod +x /tmp/health-check.sh
              /tmp/health-check.sh --slack-webhook $SLACK_WEBHOOK
          restartPolicy: OnFailure
```

#### Option 2: Systemd Service

Run as a systemd service on a monitoring host:

```ini
# /etc/systemd/system/homepage-monitor.service
[Unit]
Description=Homepage Health Monitor
After=network.target

[Service]
Type=simple
User=monitoring
ExecStart=/home/psimmons/projects/kubernetes/homepage/homepage-health-monitor.sh --continuous --interval 60 --log /var/log/homepage-health.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable homepage-monitor
sudo systemctl start homepage-monitor
sudo systemctl status homepage-monitor
```

#### Option 3: Kubernetes Deployment

Run as a long-running deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: homepage-monitor
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: homepage-monitor
  template:
    metadata:
      labels:
        app: homepage-monitor
    spec:
      serviceAccountName: homepage-monitor
      containers:
      - name: monitor
        image: bitnami/kubectl:latest
        env:
        - name: SLACK_WEBHOOK
          valueFrom:
            secretKeyRef:
              name: homepage-monitor-secrets
              key: slack-webhook
        - name: CHECK_INTERVAL
          value: "60"
        command:
        - /bin/bash
        - -c
        - |
          apt-get update && apt-get install -y curl
          curl -o /tmp/health-check.sh https://raw.githubusercontent.com/YOUR-REPO/homepage-health-monitor.sh
          chmod +x /tmp/health-check.sh
          /tmp/health-check.sh --continuous --interval ${CHECK_INTERVAL} --slack-webhook ${SLACK_WEBHOOK}
      restartPolicy: Always
```

### Service Account Setup

Create a service account with required permissions:

```bash
# Create service account
kubectl create serviceaccount homepage-monitor -n default

# Create cluster role
kubectl create clusterrole homepage-monitor --verb=get,list --resource=pods,services,endpoints,networkpolicies

# Create role binding
kubectl create clusterrolebinding homepage-monitor --clusterrole=homepage-monitor --serviceaccount=default:homepage-monitor

# Create secret for Slack webhook (if using)
kubectl create secret generic homepage-monitor-secrets \
  --from-literal=slack-webhook=https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -n default
```

## 🚨 CRITICAL: Homepage Testing Requirements

**Homepage is NOT like other Kubernetes apps - standard health checks are insufficient!**

### The Problem
- Pod shows Running ✅
- Service returns HTTP 200 ✅
- **But page displays "API Error" in widgets** ❌

### Mandatory Verification Steps

**EVERY Homepage change MUST include these checks:**

1. **HTTP Status Check** (baseline only)
   ```bash
   curl -k -s -o /dev/null -w "%{http_code}" https://homepage.petersimmons.com
   # Must return: 200
   ```

2. **HTML Content Verification** (CRITICAL)
   ```bash
   curl -k -s https://homepage.petersimmons.com | grep -i "api error"
   # Must return: (empty - no matches)
   ```

3. **Widget Rendering Check**
   ```bash
   curl -k -s https://homepage.petersimmons.com > /tmp/homepage-test.html
   grep -c "service-card" /tmp/homepage-test.html
   # Should show: expected number of services
   ```

4. **Visual Browser Verification**
   - Open https://homepage.petersimmons.com
   - Hard refresh (Ctrl+Shift+R)
   - Verify widgets show data, not "API Error"

**See `/home/psimmons/projects/kubernetes/homepage/TESTING.md` for complete testing procedures.**

**Never assume Homepage is working based on HTTP 200 alone!**

---

## Error History and Fixes

This section tracks all Homepage errors and their fixes. **Check here first when troubleshooting!**

### Error: HTML shows demo content ("My First Group") instead of actual services
**Last Seen:** 2025-12-20
**Symptoms:**
- Pod is Running, no errors in logs
- API endpoints return correct data (`/api/services` shows proper config)
- HTML page shows demo content: "My First Group", "My Second Group", "My Third Group"
- Browser shows old/cached content

**Root Cause:**
Next.js SSR (Server-Side Rendering) cache/fallback issue. The API endpoints work correctly, but the pre-rendered HTML uses fallback demo data.

**How to Diagnose:**
```bash
# Check if API endpoints return correct data
curl -k -s https://homepage.petersimmons.com/api/services | python3 -m json.tool | grep '"name"' | head -10
# Should show: your actual section names (e.g., "AI Tools", "Work", etc.)

# If API is correct but HTML shows demo content → SSR cache issue
curl -k -s https://homepage.petersimmons.com | grep -o "My First Group"
# If this returns "My First Group" → browser/SSR cache issue
```

**Fix:**
1. **Browser Hard Refresh** (Ctrl+Shift+R or Cmd+Shift+R)
2. If that doesn't work, clear browser cache for homepage.petersimmons.com
3. The APIs will load client-side and show correct data

**Note:** This is a known Homepage behavior documented in `/home/psimmons/projects/kubernetes/homepage/BROWSER_CACHE_ISSUE.md`

---

### Error: "Something went wrong" in search widget
**Last Seen:** 2025-12-20
**Symptoms:**
- Search bar displays "Something went wrong" error
- Search functionality not working
- No errors in pod logs

**Root Cause:**
Incorrect search widget configuration - using `provider: searxng` instead of `provider: custom`

**Actual Failed Configuration:**
```yaml
- search:
    provider: searxng  # ❌ Causes error
    url: https://searxng.petersimmons.com
    target: _blank
```

**Working Configuration:**
```yaml
- search:
    provider: custom  # ✅ Works
    url: https://searxng.petersimmons.com/search?q=
    target: _blank
```

**Key Points:**
- Must use `provider: custom` for SearXNG integration
- URL must include `/search?q=` parameter
- Homepage's `searxng` provider appears to have compatibility issues

**How to Diagnose:**
```bash
# Check search widget configuration
kubectl get configmap homepage -o yaml | grep -A 5 "search:"

# Should show provider: custom with full URL including ?q=
```

**Fix:**
Change provider to `custom` and ensure URL has `/search?q=` parameter

**Prevention:**
- Always test search bar after Homepage config changes
- Verify no "Something went wrong" in search widget
- Use `custom` provider for reliability

---

### Error: Widgets appear but show no dynamic data
**Last Seen:** 2025-12-20
**Symptoms:**
- Proxmox widget shows no CPU/memory/storage stats
- Pihole widgets show no query counts or blocking statistics
- Resource widgets show dashes or zeros instead of real data
- Widgets render but display static/placeholder content

**Root Causes:**
1. Widget configuration removed from ConfigMap
2. Widget backend API credentials missing/invalid
3. Network policies blocking widget API calls
4. Widget service endpoints unreachable

**Recent Documented Failures:**
- **2025-12-20**: Proxmox widget lost dynamic functionality
- **2025-12-20**: Both Pihole widgets lost dynamic functionality

**How to Diagnose:**
```bash
# Check widget configuration exists
kubectl get configmap homepage -o yaml | grep -A 30 "widgets.yaml:"

# Check for widget-specific errors
kubectl logs -n default deployment/homepage | grep -i widget

# Test widget API endpoint
curl -k https://homepage.petersimmons.com/api/widgets

# Check widget backend configs (proxmox.yaml, etc.)
kubectl get configmap homepage -o yaml | grep -A 10 "proxmox.yaml:"
```

**Fixes:**
1. Restore widget configuration from backup
2. Verify widget backend services are accessible
3. Check network policies allow widget API access
4. Validate API credentials in widget configurations
5. Test widget endpoints directly

**Prevention:**
- **ALWAYS** verify widget functionality after config changes
- Check Proxmox shows live stats
- Check Pihole widgets show query metrics
- Keep backups of working widget configurations

---

### Error: Favicons not loading or showing incorrect icons
**Last Seen:** 2025-12-20
**Symptoms:**
- Services appear but show broken/generic icons
- Specific services affected: LinkedIn, Perplexity, Linkerd
- Browser network tab may show favicon 404 errors

**Root Cause:**
Automatic favicon fetching fails for domains with non-standard favicon locations or CORS restrictions

**Recent Documented Failures & Verified Fixes:**
- **LinkedIn**: ALL URL-based icons fail (favicon.ico, CDN URLs, etc.)
  - ❌ `https://linkedin.com/favicon.ico` - Fails
  - ❌ `https://static.licdn.com/aero-v1/sc/h/al2o9zrvru7aqj8e1x2rzsrca` - Fails
  - ✅ `mdi-linkedin` - **WORKS**

- **Perplexity**: Favicon URL fails
  - ❌ `https://perplexity.ai/favicon.ico` - Fails
  - ✅ `si-perplexity` - **WORKS**

- **Linkerd**: Built-in name doesn't work, logo URL works
  - ❌ `linkerd` - May not work
  - ✅ `https://linkerd.io/logos/linkerd.png` - **WORKS**

**Verified Working Configuration (2025-12-20):**
```yaml
- LinkedIn:
    icon: mdi-linkedin  # ✅ Material Design Icons

- Linkerd:
    icon: https://linkerd.io/logos/linkerd.png  # ✅ Full logo URL

- Perplexity:
    icon: si-perplexity  # ✅ Simple Icons
```

**Key Discovery:**
LinkedIn requires Material Design Icons library (`mdi-*`). NO URL-based icon will work for LinkedIn.

**Prevention:**
- Prefer icon libraries (mdi-*, si-*) over URL-based icons
- For LinkedIn: **ALWAYS** use `mdi-linkedin`
- Always verify favicons in browser after changes
- Test in browser network tab for 404 errors

---

### Error: "API Error" in widgets despite HTTP 200
**Last Seen:** 2025-12-20
**Symptoms:**
- Homepage returns HTTP 200
- Pod is Running
- Widgets display "API Error" instead of data

**Root Causes:**
1. Widget misconfiguration in ConfigMap
2. Backend service unavailable (Proxmox, Pi-hole, etc.)
3. Network policy blocking widget API calls
4. Kubernetes auto-discovery enabled without proper RBAC

**How to Diagnose:**
```bash
# Download HTML and check for errors
curl -k -s https://homepage.petersimmons.com | grep -i "api error"

# Check pod logs for specific widget errors
kubectl logs -n default deployment/homepage --tail=100 | grep -i error

# Test internal connectivity
kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never -- \
  curl -v http://homepage-service.default.svc.cluster.local:3000
```

**Fixes:**
- Disable problematic widgets in ConfigMap
- Verify backend service accessibility
- Check network policy label selectors match pod labels
- Set `kubernetes.yaml` to `mode: disabled` if not using K8s features

---

## Common Issues Detected

### 1. Network Policy Label Mismatch (Fixed 2025-12-19)

**Symptoms:** HTTP 502 Bad Gateway, pod running but unreachable

**Root Cause:** Network policies using `app: homepage` instead of `app.kubernetes.io/name: homepage`

**Detection:** Health check compares pod labels with network policy selectors

**Fix:** Update network policies at `/home/psimmons/projects/homepage-network-policies.yaml`

### 2. API Errors in Widgets

**Symptoms:** Page loads but widgets show "API Error"

**Root Cause:** Widget misconfiguration or backend service unavailable

**Detection:** HTML content scan for error messages

**Fix:** Check widget configuration in ConfigMap and verify backend services

### 3. Pod Crash Loop

**Symptoms:** Pod restarts frequently, service unavailable

**Root Cause:** Configuration errors, resource limits, or application bugs

**Detection:** Pod status check shows non-Running state

**Fix:** Review pod logs for errors, check resource limits

## Alert Notifications

### Slack Integration

To receive alerts in Slack:

1. Create a Slack incoming webhook: https://api.slack.com/messaging/webhooks
2. Pass webhook URL to script: `--slack-webhook https://hooks.slack.com/services/...`
3. Alerts will be sent for critical failures

Example alert message:
```
🚨 Homepage Alert: Homepage not accessible from within cluster - likely network policy issue
```

### Email Integration

To add email alerts, modify the `send_slack_alert` function to also send emails:

```bash
send_email_alert() {
    local message="$1"
    echo "$message" | mail -s "Homepage Alert" admin@example.com
}
```

## Metrics and Logging

### View Logs

```bash
# If logging to file
tail -f /var/log/homepage-health.log

# If running as systemd service
journalctl -u homepage-monitor -f

# If running as Kubernetes deployment
kubectl logs -f deployment/homepage-monitor -n default
```

### Sample Log Output

```
[2025-12-19 17:15:30] [INFO] ==========================================
[2025-12-19 17:15:30] [INFO] Homepage Health Check - 2025-12-19 17:15:30
[2025-12-19 17:15:30] [INFO] ==========================================
[2025-12-19 17:15:31] [INFO] Checking pod status...
[2025-12-19 17:15:31] [SUCCESS] ✓ Pod status: 1/1 running
[2025-12-19 17:15:32] [INFO] Checking label consistency...
[2025-12-19 17:15:32] [SUCCESS] ✓ Network policy uses correct label selector
[2025-12-19 17:15:33] [INFO] Checking service endpoints...
[2025-12-19 17:15:33] [SUCCESS] ✓ Service endpoints: 10.42.4.148
[2025-12-19 17:15:34] [INFO] Checking network policies...
[2025-12-19 17:15:34] [SUCCESS] ✓ Network policies configured: 5 policies
[2025-12-19 17:15:35] [INFO] Checking pod logs for errors...
[2025-12-19 17:15:35] [SUCCESS] ✓ No errors in recent logs
[2025-12-19 17:15:36] [INFO] Checking external URL...
[2025-12-19 17:15:37] [SUCCESS] ✓ External URL: HTTP 200
[2025-12-19 17:15:38] [INFO] Checking for API errors in HTML...
[2025-12-19 17:15:38] [SUCCESS] ✓ No API errors in HTML content
[2025-12-19 17:15:38] [INFO] ==========================================
[2025-12-19 17:15:38] [SUCCESS] ✓ All health checks passed!
```

## Troubleshooting the Monitor

### Script Won't Run

```bash
# Make sure it's executable
chmod +x /home/psimmons/projects/kubernetes/homepage/homepage-health-monitor.sh

# Check dependencies
which kubectl  # Should return path to kubectl
which curl     # Should return path to curl
```

### Permission Errors

```bash
# Verify kubectl access
kubectl get pods -n default

# Check service account (if running in cluster)
kubectl auth can-i get pods --as=system:serviceaccount:default:homepage-monitor
```

### False Positives

If the monitor reports errors when Homepage is working:

1. Review the specific check that's failing
2. Adjust thresholds (e.g., error count in logs)
3. Disable specific checks if not relevant to your environment

## Maintenance

### Update the Script

```bash
# Pull latest version from git
cd /home/psimmons/projects/kubernetes/homepage
git pull

# Test changes
./homepage-health-monitor.sh

# Restart service if running as systemd
sudo systemctl restart homepage-monitor

# Or update Kubernetes deployment
kubectl rollout restart deployment/homepage-monitor -n default
```

### Adjust Check Frequency

For continuous monitoring, adjust the interval based on needs:

- **Critical production:** 30-60 seconds
- **Normal operation:** 120-300 seconds
- **Low priority:** 600+ seconds

## Documentation Updates

- **Fix applied:** 2025-12-19
- **CLAUDE.md updated:** Yes - Added network policy label requirements
- **Architecture docs updated:** Yes - Added troubleshooting section for 502 errors
- **Monitoring created:** Yes - This document and health-monitor.sh script

## Related Documentation

- CLAUDE.md - Project instructions including Homepage troubleshooting
- /home/psimmons/projects/kubernetes-cluster-documentation/applications/homepage.md - Full Homepage architecture
- /home/psimmons/projects/kubernetes/homepage/LESSONS_LEARNED.md - Historical issues and solutions
- /home/psimmons/projects/homepage-remediation-plan.md - Comprehensive remediation planning
