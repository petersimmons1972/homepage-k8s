# Homepage Quick Reference Card

**When Homepage breaks, start here.**

---

## Emergency Restoration (1 Minute)

```bash
# Restore known-good config
kubectl apply -f /home/psimmons/projects/kubernetes/homepage/configmap-updated.yaml
kubectl rollout restart deployment/homepage -n default

# Wait 30 seconds
sleep 30

# Verify
curl -k -s https://homepage.petersimmons.com | grep -i "api error" && echo "BROKEN" || echo "LOOKS OK"
```

Then do browser hard refresh: `Ctrl+Shift+R`

---

## Quick Health Check

```bash
# All must pass
kubectl get pods -l app.kubernetes.io/name=homepage  # 1/1 Running
kubectl logs deployment/homepage | grep -i error     # (empty)
curl -k -s https://homepage.petersimmons.com > /tmp/h.html
grep -i "api error" /tmp/h.html                      # (empty)
grep -i "something went wrong" /tmp/h.html           # (empty)
```

---

## Common Fixes

### Search Shows "Something went wrong"
```yaml
# Fix: Use custom provider
- search:
    provider: custom  # NOT searxng
    url: https://searxng.petersimmons.com/search?q=
    target: _blank
```

### LinkedIn Icon Broken
```yaml
# Fix: Use Material Design Icons
- LinkedIn:
    icon: mdi-linkedin  # NO URLs work
```

### Widgets Show No Data
```yaml
# Fix: Configure inline with service
- Proxmox:
    href: https://pve.petersimmons.com:8006
    icon: proxmox
    widget:  # ← Must be inline
      type: proxmox
      url: https://pve.petersimmons.com:8006
      username: root@pam!homepage
      password: f036ba38-be17-4cec-aebe-907a319cc15c
      node: pve
```

---

## Icon Library Cheat Sheet

```yaml
LinkedIn:    mdi-linkedin
Perplexity:  si-perplexity
Linkerd:     https://linkerd.io/logos/linkerd.png
Dashlane:    si-dashlane
```

---

## Testing Checklist

- [ ] HTTP 200
- [ ] No "api error" in HTML
- [ ] No "something went wrong" in HTML
- [ ] Proxmox widget shows numbers
- [ ] Pihole widgets show numbers
- [ ] Search bar works
- [ ] All icons load in browser

---

## Documentation

**Primary:** `GOLDEN-CONFIG-BASELINE.md` - Working config reference
**Testing:** `TESTING.md` - Full test procedures
**Lessons:** `LESSONS_LEARNED.md` - What we learned the hard way
**Errors:** `MONITORING.md` - Known errors and fixes

---

## Rules

- ✅ Pin version (v0.9.5)
- ✅ Verify HTML content
- ✅ Test widgets show live data
- ❌ NEVER use `:latest`
- ❌ NEVER trust HTTP 200 alone
- ❌ NEVER use `provider: searxng`
