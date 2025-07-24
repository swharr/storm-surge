#!/usr/bin/env python3
"""
Storm Surge Feature Flag Provider Setup
Interactive script to configure feature flag provider (LaunchDarkly or Statsig)
"""

import os
import sys
import json
import yaml
from typing import Dict, Any


def prompt_user_choice() -> str:
    """Prompt user to choose feature flag provider"""
    print("\n🏳️  Storm Surge Feature Flag Provider Setup")
    print("=" * 50)
    print("\nPlease choose your feature flag provider:")
    print("1. LaunchDarkly")
    print("2. Statsig")
    
    while True:
        choice = input("\nEnter your choice (1 or 2): ").strip()
        if choice == "1":
            return "launchdarkly"
        elif choice == "2":
            return "statsig"
        else:
            print("Invalid choice. Please enter 1 or 2.")


def prompt_logging_choice(feature_flag_provider: str) -> str:
    """Prompt user to choose logging provider"""
    print("\n📊 Storm Surge Logging Provider Setup")
    print("=" * 50)
    print("\nPlease choose your logging provider:")
    print("1. Auto (same as feature flag provider)")
    print("2. LaunchDarkly")
    print("3. Statsig") 
    print("4. Disabled (no logging)")
    
    while True:
        choice = input("\nEnter your choice (1-4): ").strip()
        if choice == "1":
            return "auto"
        elif choice == "2":
            return "launchdarkly"
        elif choice == "3":
            return "statsig"
        elif choice == "4":
            return "disabled"
        else:
            print("Invalid choice. Please enter 1, 2, 3, or 4.")


def prompt_docker_deployment() -> str:
    """Prompt user to choose Docker deployment strategy"""
    print("\n🐳 Storm Surge React Frontend Deployment")
    print("=" * 50)
    print("\nHow would you like to deploy the React frontend?")
    print("1. Container Registry (Production - requires Docker registry)")
    print("2. Local Build (Development - for kind/minikube)")
    print("3. Skip frontend deployment")
    
    while True:
        choice = input("\nEnter your choice (1-3): ").strip()
        if choice == "1":
            return "registry"
        elif choice == "2":
            return "local"
        elif choice == "3":
            return "skip"
        else:
            print("Invalid choice. Please enter 1-3.")


def deploy_frontend(deployment_type: str) -> bool:
    """Deploy the React frontend based on chosen strategy"""
    import subprocess
    import os
    
    if deployment_type == "skip":
        print("⏭️  Skipping frontend deployment")
        return True
    
    if not os.path.exists("frontend"):
        print("❌ Frontend directory not found. Skipping frontend deployment.")
        return False
    
    try:
        if deployment_type == "registry":
            print("\n🐳 Building and pushing to container registry...")
            print("💡 Make sure to set DOCKER_REGISTRY and DOCKER_NAMESPACE environment variables")
            
            # Run the build and push script
            result = subprocess.run(
                ["./build-and-push.sh"],
                cwd="frontend",
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                print("✅ Frontend image built and pushed successfully!")
                print("\n📋 Next steps:")
                print("1. Update your image tag in frontend/k8s/kustomization.yaml")
                print("2. Deploy: kubectl apply -k frontend/k8s/")
                return True
            else:
                print(f"❌ Failed to build/push image: {result.stderr}")
                return False
                
        elif deployment_type == "local":
            print("\n🐳 Building local Docker image...")
            
            # Run the local build script
            result = subprocess.run(
                ["./local-build.sh"],
                cwd="frontend",
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                print("✅ Frontend image built locally!")
                print("\n📋 Next steps:")
                print("1. Deploy: kubectl apply -k frontend/k8s/")
                return True
            else:
                print(f"❌ Failed to build local image: {result.stderr}")
                return False
                
    except Exception as e:
        print(f"❌ Error during frontend deployment: {e}")
        return False


def get_provider_config(provider: str, logging_provider: str) -> Dict[str, str]:
    """Get provider-specific configuration"""
    config = {}
    
    if provider == "launchdarkly":
        print(f"\n📡 Configuring {provider.title()}")
        print("-" * 30)
        config["LAUNCHDARKLY_SDK_KEY"] = input("Enter your LaunchDarkly SDK Key: ").strip()
        config["WEBHOOK_SECRET"] = input("Enter your webhook secret (optional): ").strip()
        
        print("\n📝 LaunchDarkly Setup Notes:")
        print("- Create a feature flag named 'enable-cost-optimizer' in your LaunchDarkly dashboard")
        print("- Set up a webhook pointing to: /webhook/launchdarkly")
        
    elif provider == "statsig":
        print(f"\n📡 Configuring {provider.title()}")
        print("-" * 30)
        config["STATSIG_SERVER_KEY"] = input("Enter your Statsig Server Key: ").strip()
        config["WEBHOOK_SECRET"] = input("Enter your webhook secret (optional): ").strip()
        
        print("\n📝 Statsig Setup Notes:")
        print("- Create a feature gate named 'enable_cost_optimizer' in your Statsig console")
        print("- Set up a webhook pointing to: /webhook/statsig")
    
    # Logging provider specific configuration
    if logging_provider == "launchdarkly" and provider != "launchdarkly":
        if not config.get("LAUNCHDARKLY_SDK_KEY"):
            config["LAUNCHDARKLY_SDK_KEY"] = input("Enter your LaunchDarkly SDK Key for logging: ").strip()
    elif logging_provider == "statsig" and provider != "statsig":
        if not config.get("STATSIG_SERVER_KEY"):
            config["STATSIG_SERVER_KEY"] = input("Enter your Statsig Server Key for logging: ").strip()
    
    # Common configuration
    config["SPOT_API_TOKEN"] = input("Enter your Spot API Token: ").strip()
    config["SPOT_CLUSTER_ID"] = input("Enter your Spot Cluster ID: ").strip()
    config["COST_IMPACT_THRESHOLD"] = input("Enter cost impact threshold (default 0.05): ").strip() or "0.05"
    
    return config


def update_kubernetes_configs(provider: str, logging_provider: str, config: Dict[str, str]):
    """Update Kubernetes configuration files"""
    
    # Update ConfigMap
    configmap_path = "manifests/middleware/configmap.yaml"
    try:
        with open(configmap_path, 'r') as f:
            configmap_data = yaml.safe_load_all(f)
            configmaps = list(configmap_data)
        
        # Update the first ConfigMap with new values
        if configmaps:
            configmaps[0]['data']['FEATURE_FLAG_PROVIDER'] = provider
            configmaps[0]['data']['LOGGING_PROVIDER'] = logging_provider
            configmaps[0]['data']['COST_IMPACT_THRESHOLD'] = config.get('COST_IMPACT_THRESHOLD', '0.05')
            configmaps[0]['data']['SPOT_CLUSTER_ID'] = config.get('SPOT_CLUSTER_ID', '')
            
            # Add provider-specific endpoints
            if provider == "launchdarkly":
                configmaps[0]['data']['WEBHOOK_ENDPOINT'] = "/webhook/launchdarkly"
            elif provider == "statsig":
                configmaps[0]['data']['WEBHOOK_ENDPOINT'] = "/webhook/statsig"
        
        with open(configmap_path, 'w') as f:
            yaml.dump_all(configmaps, f, default_flow_style=False)
        
        print(f"✅ Updated {configmap_path}")
        
    except Exception as e:
        print(f"❌ Error updating ConfigMap: {e}")
    
    # Update Secret template
    secret_path = "manifests/middleware/secret.yaml"
    try:
        with open(secret_path, 'r') as f:
            secret_data = yaml.safe_load(f)
        
        # Update stringData with new values
        if provider == "launchdarkly":
            secret_data['stringData']['ld-sdk-key'] = config.get('LAUNCHDARKLY_SDK_KEY', '${LAUNCHDARKLY_SDK_KEY}')
        elif provider == "statsig":
            secret_data['stringData']['statsig-server-key'] = config.get('STATSIG_SERVER_KEY', '${STATSIG_SERVER_KEY}')
        
        secret_data['stringData']['spot-api-token'] = config.get('SPOT_API_TOKEN', '${SPOT_API_TOKEN}')
        secret_data['stringData']['webhook-secret'] = config.get('WEBHOOK_SECRET', '${WEBHOOK_SECRET}')
        
        with open(secret_path, 'w') as f:
            yaml.dump(secret_data, f, default_flow_style=False)
        
        print(f"✅ Updated {secret_path}")
        
    except Exception as e:
        print(f"❌ Error updating Secret: {e}")


def update_middleware_files(provider: str):
    """Update middleware Python files with new requirements"""
    
    # Update requirements.txt with complete dependencies
    requirements_path = "manifests/middleware/requirements.txt"
    
    requirements_content = """# Core Flask web framework and server
flask==2.3.3
gunicorn==21.2.0

# HTTP requests and API communication
requests==2.31.0

# JWT token handling for authentication
PyJWT==2.8.0

# YAML parsing for configuration
pyyaml==6.0.1

# WebSocket support for real-time features
flask-socketio==5.3.6
python-socketio==5.8.0

# CORS support for cross-origin requests
flask-cors==4.0.0
"""
    
    # Add provider-specific dependencies
    if provider == "launchdarkly":
        requirements_content += "\n# LaunchDarkly SDK\nlaunchdarkly-server-sdk==8.2.1\n"
    elif provider == "statsig":
        requirements_content += "\n# Statsig SDK\nstatsig==1.20.0\n"
    
    try:
        with open(requirements_path, 'w') as f:
            f.write(requirements_content)
        
        print(f"✅ Updated {requirements_path} with {provider} dependencies")
        
    except Exception as e:
        print(f"❌ Error updating requirements: {e}")


def configure_feature_flags(interactive=True):
    """
    Configure feature flag provider for Storm Surge
    
    Args:
        interactive (bool): If True, prompt user for input. If False, use defaults.
    
    Returns:
        dict: Configuration details including provider and settings
    """
    print("🌊 Welcome to Storm Surge Feature Flag Configuration!")
    
    # Check if we're in the right directory
    if not os.path.exists("manifests/middleware"):
        print("❌ Error: Please run this script from the storm-surge root directory")
        if interactive:
            sys.exit(1)
        else:
            return {"error": "Wrong directory"}
    
    # Get user choice
    if interactive:
        provider = prompt_user_choice()
        logging_provider = prompt_logging_choice(provider)
        deployment_type = prompt_docker_deployment()
        config = get_provider_config(provider, logging_provider)
    else:
        print("Using default configuration (LaunchDarkly)")
        provider = "launchdarkly"
        logging_provider = "auto"
        deployment_type = "skip"
        config = {
            "LAUNCHDARKLY_SDK_KEY": "",
            "WEBHOOK_SECRET": "",
            "SPOT_API_TOKEN": "",
            "SPOT_CLUSTER_ID": "",
            "COST_IMPACT_THRESHOLD": "0.05"
        }
    
    # Update configuration files
    print(f"\n🔧 Updating configuration files for {provider} (logging: {logging_provider})...")
    update_kubernetes_configs(provider, logging_provider, config)
    update_middleware_files(provider)
    
    # Deploy frontend if requested
    frontend_success = True
    if interactive and deployment_type != "skip":
        frontend_success = deploy_frontend(deployment_type)
    
    print(f"\n✅ Setup completed!")
    print(f"  🏳️  Feature Flag Provider: {provider}")
    print(f"  📊 Logging Provider: {logging_provider}")
    if deployment_type != "skip":
        print(f"  🐳 Frontend Deployment: {deployment_type} ({'✅' if frontend_success else '❌'})")
    
    if interactive:
        print("\n📋 Next steps:")
        print("1. Review and update the generated configuration files")
        print("2. Deploy the middleware: kubectl apply -k manifests/middleware/")
        if deployment_type != "skip" and frontend_success:
            print("3. Deploy the frontend: kubectl apply -k frontend/k8s/")
            print("4. Configure your feature flag provider webhooks")
            print("5. Test the integration")
        else:
            print("3. Configure your feature flag provider webhooks")
            print("4. Test the integration")
        
        print(f"\n🎯 Webhook URL: <your-domain>/webhook/{provider}")
        
        if logging_provider != "disabled":
            print(f"📊 Events will be logged to: {logging_provider if logging_provider != 'auto' else provider}")
    
    return {
        "provider": provider,
        "logging_provider": logging_provider,
        "deployment_type": deployment_type,
        "frontend_success": frontend_success,
        "config": config,
        "webhook_endpoint": f"/webhook/{provider}"
    }


def main():
    """Main setup function for standalone execution"""
    return configure_feature_flags(interactive=True)


if __name__ == "__main__":
    main()