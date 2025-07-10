#!/bin/bash

INTENSITY=${1:-"moderate"}
DURATION=${2:-"300"}

echo "⚡ Starting $INTENSITY storm for ${DURATION}s"
echo "Repository: OceanSurge by Shon-Harris_flexera"

# Get frontend URL
FRONTEND_URL=$(kubectl get service frontend-service -n oceansurge -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$FRONTEND_URL" ]; then
    echo "❌ Frontend service not ready"
    echo "Check: kubectl get svc -n oceansurge"
    exit 1
fi

case $INTENSITY in
    "light")
        CONCURRENT=10
        ;;
    "moderate")
        CONCURRENT=25
        ;;
    "severe")
        CONCURRENT=50
        ;;
    "hurricane")
        CONCURRENT=100
        ;;
    *)
        echo "❌ Invalid intensity. Use: light, moderate, severe, hurricane"
        exit 1
        ;;
esac

echo "🌩️ Generating storm with $CONCURRENT concurrent requests"
echo "Target: http://$FRONTEND_URL"

# Use curl if wrk not available
if command -v wrk &> /dev/null; then
    wrk -t4 -c$CONCURRENT -d${DURATION}s http://$FRONTEND_URL
else
    echo "Using curl (install wrk for better load testing)"
    for i in $(seq 1 $CONCURRENT); do
        (
            for j in $(seq 1 $((DURATION/5))); do
                curl -s http://$FRONTEND_URL > /dev/null
                sleep 5
            done
        ) &
    done
    wait
fi

echo "✅ Storm complete!"
echo "🔍 Check scaling: kubectl get pods -n oceansurge"
