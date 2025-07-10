#!/bin/bash

echo "⚡ Lightning Strike Chaos Test"
echo "=============================="

# Simple pod chaos test
echo "🎯 Targeting shopping cart pods..."

CART_PODS=$(kubectl get pods -l app=shopping-cart -o jsonpath='{.items[*].metadata.name}')

if [ -z "$CART_PODS" ]; then
    echo "❌ No shopping cart pods found"
    exit 1
fi

# Pick random pod
POD_ARRAY=($CART_PODS)
RANDOM_POD=${POD_ARRAY[$RANDOM % ${#POD_ARRAY[@]}]}

echo "⚡ Lightning strikes pod: $RANDOM_POD"
kubectl delete pod $RANDOM_POD

echo "📊 Monitoring recovery..."
for i in {1..30}; do
    READY_PODS=$(kubectl get pods -l app=shopping-cart --field-selector=status.phase=Running --no-headers | wc -l)
    echo "Time: ${i}s - Ready pods: $READY_PODS"
    sleep 1
done

echo "✅ Lightning strike test complete!"
