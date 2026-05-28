# Homepage Golden Configuration Baseline

**Last Updated:** December 20, 2025
**Status:** ✅ VERIFIED WORKING - All widgets functional, all icons correct
**Purpose:** Reference configuration to restore Homepage when it inevitably breaks

---

## 🚨 CRITICAL: Read This First

**Homepage is the most painful Kubernetes pod in this cluster.**

If you're reading this, Homepage probably broke again. This document contains the EXACT working configuration that was verified on December 20, 2025.

**DO NOT DEVIATE** from these configurations unless you have a very good reason and a backup.

---

## Working Configuration Summary

### Image Version
```yaml
image: ghcr.io/gethomepage/homepage:v0.9.5
imagePullPolicy: IfNotPresent
```
**CRITICAL:** Do NOT use `:latest` - it breaks things

### Widget Configurations That Actually Work

#### 1. Proxmox Widget ✅
```yaml
- Proxmox:
    href: https://pve.petersimmons.com:8006
    icon: proxmox
    widget:
      type: proxmox
      url: https://pve.petersimmons.com:8006
      username: root@pam!homepage
      password: f036ba38-be17-4cec-aebe-907a319cc15c
      node: pve
```
**Shows:** Live CPU, memory, storage stats

#### 2. Pihole Widget #1 ✅
```yaml
- Pihole 231:
    href: https://192.168.0.231/admin
    icon: pi-hole
    widget:
      type: pihole
      url: http://192.168.0.231
      version: 6
      key: 6BQCd9H0JeJmLsnoYZ2q7DCwq0owTznkkxj0Ero/W8g=
```
**Shows:** DNS query counts, blocking stats

#### 3. Pihole Widget #2 ✅
```yaml
- Pihole 232:
    href: https://192.168.0.232/admin
    icon: pi-hole
    widget:
      type: pihole
      url: http://192.168.0.232
      version: 6
      key: DMnzOB1W/a2LmiTnXoXD2yCAI1R3cjTiTU2qh5iyC6Q=
```
**Shows:** DNS query counts, blocking stats

#### 4. Tailscale Widget ✅
```yaml
- Tailscale:
    href: https://login.tailscale.com/
    icon: tailscale
    widget:
      type: tailscale
      deviceid: n42sgy6CeC11CNTRL
      key: tskey-api-kbDZk13sW521CNTRL-uu7QcsV84UL9z4egfb2wTL5Zxt6i9ENk
```
**Shows:** VPN device status

### Search Widget Configuration That Works ✅
```yaml
widgets.yaml: |
  - resources:
      backend: resources
      expanded: true
      cpu: true
      memory: true
  - search:
      provider: custom  # ✅ MUST be "custom", NOT "searxng"
      url: https://searxng.petersimmons.com/search?q=  # ✅ MUST include /search?q=
      target: _blank
```

**CRITICAL:**
- Provider MUST be `custom`
- URL MUST include `/search?q=`
- Using `provider: searxng` causes "Something went wrong" error

### Icons That Actually Work ✅

**Use Icon Libraries, NOT URLs (except where noted):**

```yaml
# LinkedIn - MUST use Material Design Icons
- LinkedIn:
    icon: mdi-linkedin  # ✅ ONLY this works
    # ❌ NEVER use: https://linkedin.com/favicon.ico
    # ❌ NEVER use: https://static.licdn.com/...

# Perplexity - Use Simple Icons
- Perplexity:
    icon: si-perplexity  # ✅ Works

# Linkerd - Use full logo URL
- Linkerd:
    icon: https://linkerd.io/logos/linkerd.png  # ✅ Works

# Dashlane - Use Simple Icons
- Dashlane:
    icon: si-dashlane  # ✅ Works

# Claude services - Favicon URLs work
- Claude Usage:
    icon: https://claude.ai/favicon.ico  # ✅ Works

- Claude Desktop:
    icon: https://claude.ai/favicon.ico  # ✅ Works
```

### Other Important Settings

```yaml
kubernetes.yaml: |
  mode: disabled  # ✅ Keeps it stable

settings.yaml: |
  theme: dark
  background:
    image: https://images.unsplash.com/photo-1502790671504-542ad42d5189?auto=format&fit=crop&w=2560&q=80
    blur: sm
    saturate: 50
    brightness: 50
    opacity: 50
```

---

## Verified Service Sections (Dec 20, 2025)

### 1. AI Tools (NEW - Created Dec 20)
- Grok
- ChatGPT
- WindSurf
- Claude Usage
- Claude Desktop
- Perplexity

### 2. Work
- GMail
- LinkedIn
- GitHub

### 3. Homelab Services
- Searx
- Rancher
- Linkwarden
- Traefik
- Linkerd
- Open-WebUI
- N8N

**NOTE:** Hoarder service was removed from Homepage on 2026-01-02 as the service is no longer deployed.

### 4. News & Entertainment
- YouTube
- UnSplash
- Ground News
- X

### 5. Services
- Dashlane
- Proxmox (with widget)
- Pihole 231 (with widget)
- Pihole 232 (with widget)
- UniFi
- Tailscale (with widget)
- Truenas Scale
- Cloudflare

### 6. Financial
- Fidelity
- Motley Fool
- Seeking Alpha
- Mission Wealth

---

## What Makes Homepage So Painful

### 1. HTTP 200 Means Nothing
- Pod can be Running
- Service can return 200
- Page can still show "API Error" everywhere
- **MUST download HTML and check content**

### 2. Widget Configuration Is Fragile
- Widgets MUST be inline with services
- Missing ANY field breaks the widget
- Widget appears but shows no data when broken
- No errors in logs when widgets fail

### 3. Icon Loading Is Unreliable
- Automatic favicon fetching fails for many sites
- LinkedIn REQUIRES Material Design Icons library
- Some services need full logo URLs
- Some work with Simple Icons
- **Trial and error is often required**

### 4. Search Widget Is Picky
- `provider: searxng` doesn't work
- MUST use `provider: custom`
- MUST include `/search?q=` in URL
- Shows "Something went wrong" when misconfigured

### 5. Browser Caching Issues
- Next.js SSR can show demo content
- Must do hard refresh to see changes
- API endpoints work but HTML shows wrong data
- Confusing as hell to debug

---

## Emergency Restoration Procedure

### If Homepage Breaks Completely

1. **Restore Known-Good Configuration**
   ```bash
   # Use this exact file
   kubectl apply -f /home/psimmons/projects/kubernetes/homepage/configmap-updated.yaml

   # Restart deployment
   kubectl rollout restart deployment/homepage -n default
   kubectl rollout status deployment/homepage -n default
   ```

2. **Wait for Stabilization**
   ```bash
   sleep 30  # Give it time
   ```

3. **Verify It's Actually Working**
   ```bash
   # Download HTML and check for errors
   curl -k -s https://homepage.petersimmons.com > /tmp/homepage-test.html

   # Check for API errors
   grep -i "api error" /tmp/homepage-test.html
   # Should return: (empty)

   # Check for "something went wrong"
   grep -i "something went wrong" /tmp/homepage-test.html
   # Should return: (empty)
   ```

4. **Browser Verification**
   - Open https://homepage.petersimmons.com
   - Hard refresh: `Ctrl+Shift+R`
   - Verify widgets show live data
   - Verify search bar works
   - Verify all icons load

### If Widgets Don't Show Data

**Check that widgets are configured inline:**
```bash
kubectl get configmap homepage -o yaml | grep -A 10 "Proxmox:"
```

Should show:
```yaml
- Proxmox:
    href: https://pve.petersimmons.com:8006
    icon: proxmox
    widget:  # ← This MUST be here
      type: proxmox
      url: https://pve.petersimmons.com:8006
      # ... credentials ...
```

If `widget:` section is missing → Restore from this document

### If Search Shows "Something went wrong"

**Check search configuration:**
```bash
kubectl get configmap homepage -o yaml | grep -A 5 "search:"
```

Should show:
```yaml
- search:
    provider: custom  # ← MUST be "custom"
    url: https://searxng.petersimmons.com/search?q=  # ← MUST include ?q=
    target: _blank
```

If different → Fix it using values above

### If Icons Are Broken

**Use these exact icon specifications:**
- LinkedIn: `mdi-linkedin` (NEVER a URL)
- Perplexity: `si-perplexity`
- Linkerd: `https://linkerd.io/logos/linkerd.png`
- Dashlane: `si-dashlane`

---

## Files You Need

### Critical Files
- **Working Config**: `/home/psimmons/projects/kubernetes/homepage/configmap-updated.yaml`
- **This Document**: `/home/psimmons/projects/kubernetes/homepage/GOLDEN-CONFIG-BASELINE.md`
- **Testing Procedures**: `/home/psimmons/projects/kubernetes/homepage/TESTING.md`
- **Lessons Learned**: `/home/psimmons/projects/kubernetes/homepage/LESSONS_LEARNED.md`
- **Error History**: `/home/psimmons/projects/kubernetes/homepage/MONITORING.md`

### Backup Files (If Needed)
- **Dec 20 Pre-Session**: `configmap-backup-20251220-222524.yaml` (missing widgets)
- **Dec 2 With Widgets**: `configmap-backup-20251202.yaml` (working widgets, old structure)

---

## Testing Checklist (Every Single Time)

After ANY Homepage change:

- [ ] Pod is Running (1/1 Ready)
- [ ] No errors in logs: `kubectl logs -n default deployment/homepage | grep -i error`
- [ ] HTTP 200: `curl -k -s -o /dev/null -w "%{http_code}" https://homepage.petersimmons.com`
- [ ] Download HTML: `curl -k -s https://homepage.petersimmons.com > /tmp/test.html`
- [ ] No "api error": `grep -i "api error" /tmp/test.html` (must be empty)
- [ ] No "something went wrong": `grep -i "something went wrong" /tmp/test.html` (must be empty)
- [ ] Browser hard refresh: `Ctrl+Shift+R`
- [ ] Proxmox widget shows live stats (CPU/memory/storage numbers)
- [ ] Pihole 231 widget shows query counts
- [ ] Pihole 232 widget shows query counts
- [ ] Search bar has no error
- [ ] Search actually works (try a search)
- [ ] All icons load correctly
- [ ] No errors in browser console (F12)

**If ANY checkbox fails → Something is broken, don't assume it's fine**

---

## Rules to Live By

### DO:
- ✅ Pin to v0.9.5 (or specific tested version)
- ✅ Configure widgets inline with services
- ✅ Use icon libraries (mdi-*, si-*) over URLs
- ✅ Use `provider: custom` for search
- ✅ Always backup before changes
- ✅ Always verify HTML content, not just HTTP status
- ✅ Always test widgets show live data
- ✅ Always verify icons in browser

### DON'T:
- ❌ Use `:latest` tag
- ❌ Trust HTTP 200 status code
- ❌ Skip browser verification
- ❌ Use `provider: searxng`
- ❌ Use URL-based icons for LinkedIn
- ❌ Forget to check for "api error" in HTML
- ❌ Assume widgets work without testing
- ❌ Make changes without backup

---

## Success Criteria

**Homepage is ONLY working if ALL of these are true:**

1. ✅ HTTP 200 status
2. ✅ HTML contains zero "api error" strings
3. ✅ HTML contains zero "something went wrong" strings
4. ✅ Proxmox widget displays actual numbers (not dashes)
5. ✅ Both Pihole widgets display query counts
6. ✅ Search bar has no error message
7. ✅ Search functionality works when tested
8. ✅ All service icons load correctly
9. ✅ No errors in pod logs
10. ✅ Browser console shows no errors

**If even ONE fails → It's broken, even if it looks fine**

---

## When to Use This Document

- Homepage breaks (again)
- Widgets stop showing data
- Icons don't load
- Search shows "something went wrong"
- Rebuilding Homepage from scratch
- Training someone new on Homepage
- Whenever you think "this should be simple"

---

## Final Notes

**Homepage is deceptively complex.** It looks like a simple dashboard but has:
- Next.js SSR with cache issues
- Widget system with inline configuration
- Custom search provider requirements
- Icon fetching that fails randomly
- Silent failures that look like success

**This is why we have this document.** Stick to these configurations and you'll save yourself hours of pain.

**When Homepage breaks:** Don't try to be clever. Just restore from this baseline and verify everything works before making changes.

**Future you will thank present you for reading this.**

---

**Document Status:** ✅ VERIFIED WORKING
**Last Verified:** December 20, 2025
**Next Verification:** After any Homepage change
**Configuration File:** `/home/psimmons/projects/kubernetes/homepage/configmap-updated.yaml`
