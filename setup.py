#!/usr/bin/env python3
"""
Storm Surge Main Setup Script
Orchestrates the setup process including feature flag configuration
"""

import sys
import os
from typing import Dict, Any

def setup_storm_surge():
    """Main setup orchestrator"""
    print("🌊 Storm Surge Setup Orchestrator")
    print("=" * 40)

    # Check if we're in the right directory
    if not os.path.exists("manifests/middleware"):
        print("❌ Error: Please run this script from the storm-surge root directory")
        return False

    try:
        # Import feature flag configuration
        import feature_flag_configure

        print("\n📋 Setup Steps:")
        print("1. Feature Flag Provider Configuration")
        print("2. Kubernetes Deployment")
        print("3. Verification")

        # Step 1: Configure feature flags
        print("\n🏳️  Step 1: Feature Flag Provider Configuration")
        print("-" * 50)

        choice = input("\nWould you like to configure feature flags interactively? (y/n): ").strip().lower()

        if choice in ['y', 'yes']:
            config_result = feature_flag_configure.configure_feature_flags(interactive=True)
        else:
            print("Using default LaunchDarkly configuration...")
            config_result = feature_flag_configure.configure_feature_flags(interactive=False)

        if "error" in config_result:
            print(f"❌ Feature flag configuration failed: {config_result['error']}")
            return False

        print(f"✅ Feature flag provider configured: {config_result['provider']}")

        # Step 2: Kubernetes deployment instructions
        print("\n☸️  Step 2: Kubernetes Deployment")
        print("-" * 50)
        print("Run the following commands to deploy:")
        print("kubectl apply -k manifests/middleware/")
        print("kubectl get pods -n oceansurge")

        # Step 3: Verification instructions
        print("\n✅ Step 3: Verification")
        print("-" * 50)
        print("1. Check pod status: kubectl get pods -n oceansurge")
        print("2. Check logs: kubectl logs -n oceansurge deployment/feature-flag-middleware")
        print("3. Test health endpoint: kubectl port-forward -n oceansurge svc/feature-flag-middleware 8000:80")
        print("4. Configure webhook in your feature flag provider:")
        print(f"   - Endpoint: {config_result['webhook_endpoint']}")
        print("   - URL: https://your-domain.com" + config_result['webhook_endpoint'])

        print("\n🎉 Setup completed successfully!")
        return True

    except ImportError as e:
        print(f"❌ Failed to import feature_flag_configure: {e}")
        print("Make sure feature_flag_configure.py is in the same directory.")
        return False
    except Exception as e:
        print(f"❌ Setup failed: {e}")
        return False

def main():
    """Main function"""
    success = setup_storm_surge()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
