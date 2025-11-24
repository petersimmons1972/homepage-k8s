#!/bin/bash
# Homepage Health Check Script

echo "Checking Homepage health..."

# Check pod is running
POD_COUNT=$(kubectl get pods -n default -l app=homepage --field-selector=status.phase=Running 2>/dev/null | grep -c homepage)
if [ "$POD_COUNT" -eq 0 ]; then
    echo "❌ No running Homepage pods found"
    exit 1
fi

# Check for errors in last 2 minutes
ERROR_COUNT=$(kubectl logs -n default -l app=homepage --since=2m 2>&1 | grep -c "error")
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "❌ Found $ERROR_COUNT errors in logs (last 2 minutes)"
    echo "Recent errors:"
    kubectl logs -n default -l app=homepage --since=2m 2>&1 | grep error | head -5
    exit 1
fi

# Check API responds
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" https://homepage.petersimmons.com 2>/dev/null)
if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ HTTP error: $HTTP_CODE"
    exit 1
fi

# Check services API
SERVICES=$(curl -k -s https://homepage.petersimmons.com/api/services 2>/dev/null | jq -r '.[].name' 2>/dev/null | wc -l)
if [ "$SERVICES" -lt 5 ]; then
    echo "❌ Only $SERVICES service categories found (expected 5)"
    exit 1
fi

echo "✅ Homepage is healthy"
echo "  - Pod: Running"
echo "  - Errors: 0 (last 2 minutes)"
echo "  - HTTP: $HTTP_CODE"
echo "  - Services: $SERVICES categories"
exit 0
