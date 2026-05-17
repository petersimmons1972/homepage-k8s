# Pi-hole Widget Configuration Issue

## Problem Identified
The Pi-hole widgets are causing API errors in Homepage due to incorrect API endpoint configuration.

## Root Cause
- Pi-hole API endpoints are not responding at expected paths
- Error messages suggest using `/pi.hole/api.php` but this path returns 404
- Current API keys may be in wrong format for the Pi-hole versions running

## Current Configuration
```yaml
- Pihole 231:
    href: https://192.168.0.231/admin
    icon: pi-hole
    widget:
      type: pihole
      url: https://192.168.0.231
      key: CKEkaGUykGP2cLBKA2xuzJY8nf80tPgfgjf0RvjYaJc=

- Pihole 232:
    href: https://192.168.0.232/admin
    icon: pi-hole
    widget:
      type: pihole
      url: https://192.168.0.232
      key: uEgtIjqsdM7MfQ6+f2n93Q1pnm7IWhT+yAmvZ1CsAtY=
```

## Issues Found
1. **API Path**: Both Pi-holes return error "The API is hosted at pi.hole/api, not pi.hole/admin/api"
2. **Wrong Endpoint**: When trying `/pi.hole/api.php`, returns 404 Not Found
3. **Version Compatibility**: API keys may not be compatible with current Pi-hole versions

## Testing Results
- ✅ Homepage APIs work correctly
- ✅ All other services configured properly
- ✅ Zero errors when Pi-hole widgets are disabled
- ❌ Pi-hole widgets cause API errors when enabled

## Resolution Required
1. **Determine correct Pi-hole API endpoints** for the specific versions running
2. **Verify API key format** (may need different format for newer Pi-hole versions)
3. **Update widget configuration** with correct API paths

## Current Status
Homepage is fully functional without Pi-hole widgets. All 30 services across 5 categories are working correctly. Only Pi-hole widgets need to be reconfigured once the correct API endpoints are determined.

## Next Steps
1. Access Pi-hole admin interfaces to determine actual API documentation
2. Test different API endpoint formats
3. Update configuration with working API paths
4. Re-enable Pi-hole widgets with correct configuration