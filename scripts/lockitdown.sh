#!/bin/bash
set -e

# This function checks if a Kubernetes resource is using the insecure port 10255.
#
# Arguments:
#  $1 - Resource type (e.g., pod, configmap, )
#  $2 - Resource name
#  $3 - Namespace
#
# Output:
#  Prints a message indicating whether the resource is using the insecure port.
isUsingInsecurePort() {
  resource_type=$1
  resource_name=$2
  namespace=$3

  config=$(kubectl get $resource_type $resource_name -n $namespace -o yaml)

  # Check if kubectl output is empty
  if [[ -z "$config" ]]; then
    echo "No configuration file detected for $resource_type: $resource_name (Namespace: $namespace)"
    return
  fi

  if echo "$config" | grep -q "10255"; then
    echo "Warning: The configuration file ($resource_type: $namespace/$resource_name) is using insecure port 10255. It is recommended to migrate to port 10250 for enhanced security."
  else
    echo "Info: The configuration file ($resource_type: $namespace/$resource_name) is not using insecure port 10255."
  fi
}

# Get the list of ConfigMaps with their namespaces
configmaps=$(kubectl get configmaps -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name | tail -n +2 | awk '{print $1"/"$2}')

# Iterate over each ConfigMap
for configmap in $configmaps; do
  namespace=$(echo $configmap | cut -d/ -f1)
  configmap_name=$(echo $configmap | cut -d/ -f2)
  isUsingInsecurePort "configmap" "$configmap_name" "$namespace"
done

# Get the list of Pods with their namespaces
pods=$(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name | tail -n +2 | awk '{print $1"/"$2}')

# Iterate over each Pod
for pod in $pods; do
  namespace=$(echo $pod | cut -d/ -f1)
  pod_name=$(echo $pod | cut -d/ -f2)
  isUsingInsecurePort "pod" "$pod_name" "$namespace"
done
