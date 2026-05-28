#!/bin/bash
#
# Homepage Health Monitor
# Comprehensive health check script for Homepage Kubernetes app
# This script addresses the recurring Homepage failures mentioned in user requirements
#
# Usage:
#   ./homepage-health-monitor.sh [--continuous] [--interval SECONDS]
#
# Options:
#   --continuous    Run continuously in a loop
#   --interval N    Check interval in seconds (default: 60)
#   --slack-webhook URL  Send alerts to Slack webhook
#   --log FILE      Log output to file
#

set -euo pipefail

# Configuration
NAMESPACE="default"
APP_LABEL="app.kubernetes.io/name=homepage"
SERVICE_NAME="homepage-service"
SERVICE_PORT="3000"
EXTERNAL_URL="https://homepage.petersimmons.com"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
LOG_FILE="${LOG_FILE:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
CONTINUOUS=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --continuous)
            CONTINUOUS=true
            shift
            ;;
        --interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        --slack-webhook)
            SLACK_WEBHOOK="$2"
            shift 2
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging function
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        *)
            echo -e "[INFO] $message"
            ;;
    esac

    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# Slack notification function
send_slack_alert() {
    local message="$1"

    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"🚨 Homepage Alert: $message\"}" > /dev/null 2>&1 || true
    fi
}

# Check if pod is running
check_pod_status() {
    log INFO "Checking pod status..."

    local pod_count=$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers 2>/dev/null | wc -l)

    if [[ $pod_count -eq 0 ]]; then
        log ERROR "No Homepage pods found!"
        send_slack_alert "No Homepage pods found in namespace $NAMESPACE"
        return 1
    fi

    local running_pods=$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

    if [[ $running_pods -eq 0 ]]; then
        log ERROR "No Homepage pods in Running state!"
        send_slack_alert "Homepage pods exist but none are Running"
        return 1
    fi

    log SUCCESS "✓ Pod status: $running_pods/$pod_count running"
    return 0
}

# Check pod labels match network policies
check_label_consistency() {
    log INFO "Checking label consistency..."

    local pod_labels=$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers -o jsonpath='{.items[0].metadata.labels}' 2>/dev/null)

    if [[ -z "$pod_labels" ]]; then
        log ERROR "Could not get pod labels!"
        return 1
    fi

    # Check network policy selector
    local netpol_selector=$(kubectl get networkpolicy allow-traefik-to-homepage -n "$NAMESPACE" -o jsonpath='{.spec.podSelector.matchLabels}' 2>/dev/null)

    if echo "$netpol_selector" | grep -q "app.kubernetes.io/name"; then
        log SUCCESS "✓ Network policy uses correct label selector"
    else
        log ERROR "Network policy label mismatch! Should use app.kubernetes.io/name=homepage"
        send_slack_alert "Network policy label mismatch detected - this will cause 502 errors!"
        return 1
    fi

    return 0
}

# Check pod logs for errors
check_pod_logs() {
    log INFO "Checking pod logs for errors..."

    local error_count=$(kubectl logs -n "$NAMESPACE" -l "$APP_LABEL" --tail=100 --since=5m 2>/dev/null | grep -ci "error" || true)

    if [[ $error_count -gt 10 ]]; then
        log WARN "High error count in logs: $error_count errors in last 5 minutes"
        send_slack_alert "High error count detected in Homepage logs: $error_count errors"
        return 1
    elif [[ $error_count -gt 0 ]]; then
        log WARN "Some errors found in logs: $error_count errors in last 5 minutes"
    else
        log SUCCESS "✓ No errors in recent logs"
    fi

    return 0
}

# Check service endpoints
check_service_endpoints() {
    log INFO "Checking service endpoints..."

    local endpoints=$(kubectl get endpoints "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)

    if [[ -z "$endpoints" ]]; then
        log ERROR "No endpoints found for service $SERVICE_NAME!"
        send_slack_alert "Homepage service has no endpoints - pods not matching service selector"
        return 1
    fi

    log SUCCESS "✓ Service endpoints: $endpoints"
    return 0
}

# Check internal connectivity
check_internal_connectivity() {
    log INFO "Checking internal cluster connectivity..."

    # Create a temporary pod for testing
    kubectl run homepage-health-test --image=curlimages/curl:latest --restart=Never --command -- sleep 60 > /dev/null 2>&1 || {
        log WARN "Could not create test pod (may already exist), cleaning up..."
        kubectl delete pod homepage-health-test --wait=false > /dev/null 2>&1 || true
        sleep 2
        kubectl run homepage-health-test --image=curlimages/curl:latest --restart=Never --command -- sleep 60 > /dev/null 2>&1 || {
            log WARN "Skipping internal connectivity check - cannot create test pod"
            return 0
        }
    }

    # Wait for pod to be ready
    log INFO "Waiting for test pod to be ready..."
    local wait_count=0
    while [[ $wait_count -lt 30 ]]; do
        local pod_status=$(kubectl get pod homepage-health-test -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [[ "$pod_status" == "Running" ]]; then
            break
        fi
        sleep 1
        ((wait_count++))
    done

    if [[ $wait_count -ge 30 ]]; then
        log WARN "Test pod did not become ready in time, skipping internal connectivity check"
        kubectl delete pod homepage-health-test --wait=false > /dev/null 2>&1 || true
        return 0
    fi

    # Test connectivity
    local test_result=$(kubectl exec homepage-health-test -- curl -s -o /dev/null -w "%{http_code}" "http://$SERVICE_NAME.$NAMESPACE.svc.cluster.local:$SERVICE_PORT" 2>/dev/null || echo "FAILED")

    # Clean up test pod
    kubectl delete pod homepage-health-test --wait=false > /dev/null 2>&1 || true

    if [[ "$test_result" == "200" ]]; then
        log SUCCESS "✓ Internal connectivity: HTTP 200"
        return 0
    else
        log ERROR "Internal connectivity failed: $test_result"
        send_slack_alert "Homepage not accessible from within cluster - likely network policy issue"
        return 1
    fi
}

# Check external URL
check_external_url() {
    log INFO "Checking external URL..."

    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$EXTERNAL_URL" 2>&1 || echo "FAILED")

    if [[ "$http_code" == "200" ]]; then
        log SUCCESS "✓ External URL: HTTP $http_code"
    else
        log ERROR "External URL check failed: HTTP $http_code"
        send_slack_alert "Homepage returning $http_code at $EXTERNAL_URL"
        return 1
    fi

    return 0
}

# Check for API errors in HTML
check_api_errors() {
    log INFO "Checking for API errors in HTML..."

    local html_content=$(curl -s "$EXTERNAL_URL" 2>&1)

    # Check for actual API error display (not just i18n strings)
    # Look for visible API Error messages in the rendered content
    if echo "$html_content" | grep -E 'class="[^"]*error[^"]*"|>API Error<|api.*error.*displayed|Error.*API' | grep -qv 'api_error.*:'; then
        # Exclude false positives from i18n translation keys
        if ! echo "$html_content" | grep -q '"api_error":"API Error"'; then
            log ERROR "API errors detected in Homepage HTML!"
            send_slack_alert "Homepage is accessible but contains API errors"
            return 1
        fi
    fi

    log SUCCESS "✓ No API errors in HTML content"
    return 0
}

# Check network policies
check_network_policies() {
    log INFO "Checking network policies..."

    local policies=$(kubectl get networkpolicies -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)

    if [[ $policies -eq 0 ]]; then
        log WARN "No network policies found in namespace $NAMESPACE"
    else
        log SUCCESS "✓ Network policies configured: $policies policies"
    fi

    return 0
}

# Run all health checks
run_health_checks() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local failed_checks=0

    echo ""
    log INFO "=========================================="
    log INFO "Homepage Health Check - $timestamp"
    log INFO "=========================================="
    echo ""

    check_pod_status || ((failed_checks++))
    check_label_consistency || ((failed_checks++))
    check_service_endpoints || ((failed_checks++))
    check_network_policies || ((failed_checks++))
    check_pod_logs || ((failed_checks++))
    check_internal_connectivity || ((failed_checks++))
    check_external_url || ((failed_checks++))
    check_api_errors || ((failed_checks++))

    echo ""
    log INFO "=========================================="

    if [[ $failed_checks -eq 0 ]]; then
        log SUCCESS "✓ All health checks passed!"
        echo ""
        return 0
    else
        log ERROR "✗ $failed_checks health check(s) failed!"
        echo ""
        return 1
    fi
}

# Main execution
main() {
    if [[ "$CONTINUOUS" == true ]]; then
        log INFO "Starting continuous monitoring (interval: ${CHECK_INTERVAL}s)"
        log INFO "Press Ctrl+C to stop"
        echo ""

        while true; do
            run_health_checks
            log INFO "Next check in ${CHECK_INTERVAL} seconds..."
            sleep "$CHECK_INTERVAL"
        done
    else
        run_health_checks
    fi
}

main
