#!/bin/bash
set -e

# Conference Demo Load Testing Script
# Generates realistic load to demonstrate Kubernetes scaling

echo "🚀 Storm Surge Load Testing for Conference Demo"
echo "=============================================="
echo

# Configuration
NAMESPACE="oceansurge"
LOAD_DURATION=${LOAD_DURATION:-300}  # 5 minutes default
CONCURRENT_USERS=${CONCURRENT_USERS:-10}
RAMP_UP_TIME=${RAMP_UP_TIME:-60}  # 1 minute ramp up

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get frontend service details
echo "🔍 Detecting frontend service..."
FRONTEND_SERVICE=$(kubectl get service frontend-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -z "$FRONTEND_SERVICE" ]; then
    FRONTEND_SERVICE=$(kubectl get service frontend-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
fi

if [ -z "$FRONTEND_SERVICE" ]; then
    echo "⚠️  LoadBalancer IP not yet assigned, using port-forward method"
    USE_PORT_FORWARD=true
    FRONTEND_URL="http://localhost:8080"
else
    USE_PORT_FORWARD=false
    FRONTEND_URL="http://$FRONTEND_SERVICE"
    echo "✅ Frontend accessible at: $FRONTEND_URL"
fi

# Function to start port-forward if needed
start_port_forward() {
    if [ "$USE_PORT_FORWARD" = "true" ]; then
        echo "🔀 Starting port-forward to frontend service..."
        kubectl port-forward svc/frontend-service 8080:80 -n $NAMESPACE &
        PORT_FORWARD_PID=$!
        sleep 5  # Wait for port-forward to establish
        echo "✅ Port-forward active (PID: $PORT_FORWARD_PID)"
    fi
}

# Function to stop port-forward if needed
stop_port_forward() {
    if [ "$USE_PORT_FORWARD" = "true" ] && [ ! -z "$PORT_FORWARD_PID" ]; then
        echo "🛑 Stopping port-forward..."
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
}

# Trap to clean up port-forward on exit
trap stop_port_forward EXIT

# Function to check if frontend is responsive
check_frontend() {
    local url="$1"
    local max_attempts=30
    local attempt=1
    
    echo "🔍 Checking frontend responsiveness..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s --max-time 5 "$url" >/dev/null 2>&1; then
            echo "✅ Frontend is responding"
            return 0
        fi
        
        echo "   Attempt $attempt/$max_attempts - waiting for frontend..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "❌ Frontend not responding after $max_attempts attempts"
    return 1
}

# Function to get initial metrics
get_initial_metrics() {
    echo "📊 Collecting initial metrics..."
    
    echo "Initial Pod Count:"
    kubectl get pods -n $NAMESPACE -l app=shopping-cart --no-headers | wc -l | xargs echo "  Shopping Cart Pods:"
    kubectl get pods -n $NAMESPACE -l app=frontend --no-headers | wc -l | xargs echo "  Frontend Pods:"
    kubectl get pods -n $NAMESPACE -l app=product-catalog --no-headers | wc -l | xargs echo "  Product Catalog Pods:"
    
    echo
    echo "HPA Status:"
    kubectl get hpa -n $NAMESPACE --no-headers 2>/dev/null || echo "  HPA not available"
    
    echo
    echo "Resource Usage:"
    kubectl top pods -n $NAMESPACE --no-headers 2>/dev/null || echo "  Metrics not available"
    echo
}

# Function to monitor scaling during load test
monitor_scaling() {
    local duration="$1"
    local monitor_file="/tmp/scaling_monitor.log"
    
    echo "📈 Starting scaling monitor (duration: ${duration}s)..."
    echo "Timestamp,ShoppingCartPods,FrontendPods,ProductCatalogPods,ShoppingCartCPU,FrontendCPU" > "$monitor_file"
    
    local end_time=$(($(date +%s) + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local cart_pods=$(kubectl get pods -n $NAMESPACE -l app=shopping-cart --no-headers 2>/dev/null | wc -l)
        local frontend_pods=$(kubectl get pods -n $NAMESPACE -l app=frontend --no-headers 2>/dev/null | wc -l)
        local catalog_pods=$(kubectl get pods -n $NAMESPACE -l app=product-catalog --no-headers 2>/dev/null | wc -l)
        
        # Get HPA metrics
        local cart_cpu=$(kubectl get hpa shopping-cart-hpa -n $NAMESPACE -o jsonpath='{.status.currentCPUUtilizationPercentage}' 2>/dev/null || echo "0")
        local frontend_cpu=$(kubectl get hpa frontend-hpa -n $NAMESPACE -o jsonpath='{.status.currentCPUUtilizationPercentage}' 2>/dev/null || echo "0")
        
        echo "$timestamp,$cart_pods,$frontend_pods,$catalog_pods,$cart_cpu%,$frontend_cpu%" >> "$monitor_file"
        
        # Display real-time status
        printf "\r⚡ Cart: %2d pods (%3s%% CPU) | Frontend: %2d pods (%3s%% CPU) | Catalog: %2d pods" \
               "$cart_pods" "$cart_cpu" "$frontend_pods" "$frontend_cpu" "$catalog_pods"
        
        sleep 10
    done
    
    echo
    echo "📊 Scaling monitor complete. Data saved to: $monitor_file"
}

# Function to generate load using multiple methods
generate_load() {
    local url="$1"
    local duration="$2"
    local concurrent="$3"
    
    echo "🎯 Generating load for ${duration}s with ${concurrent} concurrent connections..."
    echo "   Target: $url"
    
    # Create load generator pod if using cluster-internal method
    if [ "$USE_PORT_FORWARD" = "false" ]; then
        kubectl run load-generator-demo \
            --image=alpine/curl:latest \
            --rm -i --restart=Never \
            --timeout=$((duration + 60))s \
            --overrides='{
                "spec": {
                    "containers": [{
                        "name": "load-generator-demo",
                        "image": "alpine/curl:latest",
                        "command": ["/bin/sh"],
                        "args": ["-c", "
                            echo \"Starting load generation...\";
                            end_time=$(($(date +%s) + '$duration'));
                            while [ $(date +%s) -lt $end_time ]; do
                                for i in $(seq 1 '$concurrent'); do
                                    (curl -s --max-time 5 '$url' >/dev/null 2>&1 &);
                                done;
                                sleep 1;
                            done;
                            echo \"Load generation complete\";
                        "],
                        "resources": {
                            "limits": {"cpu": "500m", "memory": "256Mi"},
                            "requests": {"cpu": "100m", "memory": "128Mi"}
                        }
                    }]
                }
            }' &
        LOAD_GEN_PID=$!
    else
        # Use local curl for port-forward method
        echo "🔄 Using local curl for load generation..."
        local end_time=$(($(date +%s) + duration))
        
        while [ $(date +%s) -lt $end_time ]; do
            for i in $(seq 1 $concurrent); do
                curl -s --max-time 5 "$url" >/dev/null 2>&1 &
            done
            sleep 1
        done
    fi
}

# Function to display results
show_results() {
    local monitor_file="/tmp/scaling_monitor.log"
    
    echo
    echo "📈 LOAD TEST RESULTS"
    echo "===================="
    
    echo "Final Pod Count:"
    kubectl get pods -n $NAMESPACE -l app=shopping-cart --no-headers | wc -l | xargs echo "  Shopping Cart Pods:"
    kubectl get pods -n $NAMESPACE -l app=frontend --no-headers | wc -l | xargs echo "  Frontend Pods:"
    kubectl get pods -n $NAMESPACE -l app=product-catalog --no-headers | wc -l | xargs echo "  Product Catalog Pods:"
    
    echo
    echo "Final HPA Status:"
    kubectl get hpa -n $NAMESPACE 2>/dev/null || echo "  HPA not available"
    
    echo
    echo "Resource Usage After Load:"
    kubectl top pods -n $NAMESPACE 2>/dev/null || echo "  Metrics not available"
    
    if [ -f "$monitor_file" ]; then
        echo
        echo "📊 Scaling Timeline (last 10 measurements):"
        echo "Time                Shopping  Frontend  Product   Cart   Frontend"
        echo "                   Cart Pods    Pods  Cat Pods  CPU%    CPU%"
        echo "----------------------------------------------------------------"
        tail -10 "$monitor_file" | while IFS=',' read timestamp cart_pods frontend_pods catalog_pods cart_cpu frontend_cpu; do
            printf "%-18s %4s      %4s      %4s    %6s  %6s\n" \
                   "$timestamp" "$cart_pods" "$frontend_pods" "$catalog_pods" "$cart_cpu" "$frontend_cpu"
        done
    fi
    
    echo
    echo "✅ Load test complete! Key observations:"
    echo "   • Check if shopping cart scaled up under load"
    echo "   • Verify HPA responded to CPU metrics"
    echo "   • Monitor how long scaling took to respond"
    echo "   • Observe scaling behavior in Grafana dashboards"
}

# Main execution
echo "🎬 Starting Conference Demo Load Test"
echo "Duration: ${LOAD_DURATION}s | Concurrent Users: ${CONCURRENT_USERS}"
echo

# Start port-forward if needed
start_port_forward

# Check frontend availability
if ! check_frontend "$FRONTEND_URL"; then
    echo "❌ Cannot proceed with load test - frontend not accessible"
    exit 1
fi

# Get initial metrics
get_initial_metrics

# Start monitoring in background
monitor_scaling "$LOAD_DURATION" &
MONITOR_PID=$!

# Wait for monitoring to start
sleep 2

# Generate load
generate_load "$FRONTEND_URL" "$LOAD_DURATION" "$CONCURRENT_USERS"

# Wait for monitoring to complete
wait $MONITOR_PID 2>/dev/null || true

# Show results
show_results

echo
echo "🎉 Conference demo load test completed successfully!"
echo
echo "📋 Next steps for demo:"
echo "   • Open Grafana: kubectl port-forward svc/grafana-service 3000:3000 -n monitoring"
echo "   • View scaling events: kubectl get events -n $NAMESPACE | grep -i scale"
echo "   • Monitor pod status: watch kubectl get pods -n $NAMESPACE"
echo "   • Check HPA status: watch kubectl get hpa -n $NAMESPACE"