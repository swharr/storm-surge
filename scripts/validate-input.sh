#!/bin/bash
# Input validation functions for deployment scripts

# Validate cluster name (alphanumeric and hyphens only, no leading/trailing hyphens)
validate_cluster_name() {
    local name=$1
    if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]] || [[ ${#name} -gt 63 ]]; then
        echo "Invalid cluster name: $name"
        echo "Must be alphanumeric with hyphens, max 63 chars, no leading/trailing hyphens"
        return 1
    fi
    return 0
}

# Validate region format
validate_region() {
    local provider=$1
    local region=$2
    
    case $provider in
        gke)
            if [[ ! "$region" =~ ^[a-z]+-[a-z]+[0-9]*$ ]]; then
                echo "Invalid GKE region format: $region"
                return 1
            fi
            ;;
        eks)
            if [[ ! "$region" =~ ^[a-z]+-[a-z]+-[0-9]$ ]]; then
                echo "Invalid EKS region format: $region"
                return 1
            fi
            ;;
        aks)
            if [[ ! "$region" =~ ^[a-z]+[0-9]*$ ]]; then
                echo "Invalid AKS region format: $region"
                return 1
            fi
            ;;
        *)
            echo "Unknown provider: $provider"
            return 1
            ;;
    esac
    return 0
}

# Validate zone format
validate_zone() {
    local provider=$1
    local zone=$2
    
    case $provider in
        gke)
            if [[ ! "$zone" =~ ^[a-z]+-[a-z]+[0-9]*-[a-z]$ ]]; then
                echo "Invalid GKE zone format: $zone"
                return 1
            fi
            ;;
        eks)
            # EKS uses multiple zones
            for z in $zone; do
                if [[ ! "$z" =~ ^[a-z]+-[a-z]+-[0-9][a-z]$ ]]; then
                    echo "Invalid EKS zone format: $z"
                    return 1
                fi
            done
            ;;
        aks)
            if [[ ! "$zone" =~ ^[1-3]$ ]]; then
                echo "Invalid AKS zone: $zone (must be 1, 2, or 3)"
                return 1
            fi
            ;;
    esac
    return 0
}

# Validate node count
validate_node_count() {
    local nodes=$1
    if [[ ! "$nodes" =~ ^[0-9]+$ ]] || [ "$nodes" -lt 1 ] || [ "$nodes" -gt 10 ]; then
        echo "Invalid node count: $nodes (must be 1-10)"
        return 1
    fi
    return 0
}

# Sanitize environment variable values
sanitize_env_value() {
    local value=$1
    # Remove potentially dangerous characters
    echo "$value" | sed 's/[;&|`$(){}]//g' | tr -d '\n'
}

# Validate AWS profile name
validate_aws_profile() {
    local profile=$1
    if [[ ! "$profile" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Invalid AWS profile name: $profile"
        return 1
    fi
    return 0
}

# Validate file path (no traversal attacks)
validate_file_path() {
    local path=$1
    if [[ "$path" == *".."* ]] || [[ "$path" == *"~"* ]]; then
        echo "Invalid file path: $path (no directory traversal allowed)"
        return 1
    fi
    return 0
}

# Export functions for use in other scripts
export -f validate_cluster_name
export -f validate_region
export -f validate_zone
export -f validate_node_count
export -f sanitize_env_value
export -f validate_aws_profile
export -f validate_file_path