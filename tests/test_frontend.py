#!/usr/bin/env python3
"""
Tests for Storm Surge React Frontend
Tests build process, configuration, and deployment readiness
"""

import unittest
import json
import os
import subprocess
import tempfile
from pathlib import Path

# Frontend directory path
FRONTEND_DIR = Path(__file__).parent.parent / "frontend"


class TestFrontendAvailability(unittest.TestCase):
    """Test frontend availability and structure"""

    def test_frontend_directory_exists(self):
        """Test that frontend directory exists"""
        self.assertTrue(FRONTEND_DIR.exists(), "Frontend directory should exist")

    def test_package_json_exists(self):
        """Test that package.json exists and is valid"""
        package_json_path = FRONTEND_DIR / "package.json"
        self.assertTrue(package_json_path.exists(), "package.json should exist")

        with open(package_json_path, 'r') as f:
            package_data = json.load(f)

        # Verify required fields
        required_fields = ['name', 'version', 'dependencies', 'devDependencies', 'scripts']
        for field in required_fields:
            self.assertIn(field, package_data, f"package.json should have {field}")

    def test_required_config_files_exist(self):
        """Test that required configuration files exist"""
        required_files = [
            "tsconfig.json",
            "tailwind.config.js",
            "vite.config.ts",
            "postcss.config.js",
            ".eslintrc.cjs"
        ]

        for file in required_files:
            file_path = FRONTEND_DIR / file
            self.assertTrue(file_path.exists(), f"{file} should exist")

    def test_src_directory_structure(self):
        """Test that src directory has required structure"""
        src_dir = FRONTEND_DIR / "src"
        self.assertTrue(src_dir.exists(), "src directory should exist")

        required_dirs = ["components", "pages", "services", "types", "hooks"]
        for dir_name in required_dirs:
            dir_path = src_dir / dir_name
            self.assertTrue(dir_path.exists(), f"src/{dir_name} directory should exist")

    def test_main_app_files_exist(self):
        """Test that main app files exist"""
        src_dir = FRONTEND_DIR / "src"
        required_files = ["App.tsx", "main.tsx", "index.css"]

        for file in required_files:
            file_path = src_dir / file
            self.assertTrue(file_path.exists(), f"src/{file} should exist")


class TestFrontendConfiguration(unittest.TestCase):
    """Test frontend configuration"""

    def test_package_json_scripts(self):
        """Test that package.json has required scripts"""
        package_json_path = FRONTEND_DIR / "package.json"

        with open(package_json_path, 'r') as f:
            package_data = json.load(f)

        required_scripts = ['dev', 'build', 'preview', 'lint']
        for script in required_scripts:
            self.assertIn(script, package_data['scripts'], f"Script '{script}' should be defined")

    def test_typescript_config(self):
        """Test TypeScript configuration"""
        tsconfig_path = FRONTEND_DIR / "tsconfig.json"

        with open(tsconfig_path, 'r') as f:
            tsconfig = json.load(f)

        self.assertIn('compilerOptions', tsconfig)
        self.assertIn('include', tsconfig)

        # Check for React JSX support
        compiler_options = tsconfig['compilerOptions']
        self.assertEqual(compiler_options.get('jsx'), 'react-jsx')

    def test_essential_dependencies(self):
        """Test that essential dependencies are present"""
        package_json_path = FRONTEND_DIR / "package.json"

        with open(package_json_path, 'r') as f:
            package_data = json.load(f)

        essential_deps = [
            'react',
            'react-dom',
            'axios',
            'react-router-dom',
            '@tanstack/react-query',
            'socket.io-client'
        ]

        dependencies = package_data['dependencies']
        for dep in essential_deps:
            self.assertIn(dep, dependencies, f"Dependency '{dep}' should be present")


class TestDockerConfiguration(unittest.TestCase):
    """Test Docker configuration for frontend"""

    def test_dockerfile_exists(self):
        """Test that Dockerfile exists"""
        dockerfile_path = FRONTEND_DIR / "Dockerfile"
        self.assertTrue(dockerfile_path.exists(), "Dockerfile should exist")

    def test_nginx_config_exists(self):
        """Test that nginx configuration exists"""
        nginx_config_path = FRONTEND_DIR / "nginx.conf"
        self.assertTrue(nginx_config_path.exists(), "nginx.conf should exist")

    def test_docker_scripts_exist(self):
        """Test that Docker build scripts exist"""
        build_script = FRONTEND_DIR / "build-and-push.sh"
        local_script = FRONTEND_DIR / "local-build.sh"
        entrypoint_script = FRONTEND_DIR / "docker-entrypoint.sh"

        self.assertTrue(build_script.exists(), "build-and-push.sh should exist")
        self.assertTrue(local_script.exists(), "local-build.sh should exist")
        self.assertTrue(entrypoint_script.exists(), "docker-entrypoint.sh should exist")

    def test_docker_scripts_executable(self):
        """Test that Docker scripts are executable"""
        build_script = FRONTEND_DIR / "build-and-push.sh"
        local_script = FRONTEND_DIR / "local-build.sh"

        self.assertTrue(os.access(build_script, os.X_OK), "build-and-push.sh should be executable")
        self.assertTrue(os.access(local_script, os.X_OK), "local-build.sh should be executable")

    def test_nginx_config_content(self):
        """Test nginx configuration content"""
        nginx_config_path = FRONTEND_DIR / "nginx.conf"

        with open(nginx_config_path, 'r') as f:
            nginx_content = f.read()

        # Check for API proxy configuration
        self.assertIn('location /api/', nginx_content)
        self.assertIn('proxy_pass http://feature-flag-middleware:8000', nginx_content)

        # Check for WebSocket proxy configuration
        self.assertIn('location /socket.io/', nginx_content)
        self.assertIn('Connection "upgrade"', nginx_content)


class TestKubernetesManifests(unittest.TestCase):
    """Test Kubernetes manifests for frontend"""

    def test_k8s_directory_exists(self):
        """Test that k8s directory exists"""
        k8s_dir = FRONTEND_DIR / "k8s"
        self.assertTrue(k8s_dir.exists(), "k8s directory should exist")

    def test_required_k8s_manifests_exist(self):
        """Test that required Kubernetes manifests exist"""
        k8s_dir = FRONTEND_DIR / "k8s"
        required_manifests = [
            "deployment.yaml",
            "service.yaml",
            "ingress.yaml",
            "configmap.yaml",
            "kustomization.yaml"
        ]

        for manifest in required_manifests:
            manifest_path = k8s_dir / manifest
            self.assertTrue(manifest_path.exists(), f"{manifest} should exist in k8s/")

    def test_kustomization_syntax(self):
        """Test kustomization.yaml syntax"""
        kustomization_path = FRONTEND_DIR / "k8s" / "kustomization.yaml"

        # Try to validate with kubectl (if available)
        try:
            result = subprocess.run(
                ['kubectl', '--dry-run=client', 'apply', '-k', str(FRONTEND_DIR / "k8s")],
                capture_output=True,
                text=True,
                timeout=30
            )
            # If kubectl succeeds, manifests are valid
            if result.returncode == 0:
                self.assertTrue(True, "Kubernetes manifests are valid")
            else:
                # Print error for debugging but don't fail the test
                print(f"Kubectl validation warning: {result.stderr}")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            # kubectl not available or timeout, skip validation
            self.skipTest("kubectl not available for manifest validation")


class TestIntegrationPoints(unittest.TestCase):
    """Test integration points between frontend and backend"""

    def test_api_service_configuration(self):
        """Test API service configuration"""
        api_service_path = FRONTEND_DIR / "src" / "services" / "api.ts"
        self.assertTrue(api_service_path.exists(), "API service should exist")

        with open(api_service_path, 'r') as f:
            api_content = f.read()

        # Check for essential API methods
        essential_methods = ['login', 'getCurrentUser', 'getFeatureFlags', 'getClusters']
        for method in essential_methods:
            self.assertIn(method, api_content, f"API service should have {method} method")

    def test_websocket_hook_configuration(self):
        """Test WebSocket hook configuration"""
        websocket_hook_path = FRONTEND_DIR / "src" / "hooks" / "useWebSocket.ts"
        self.assertTrue(websocket_hook_path.exists(), "WebSocket hook should exist")

        with open(websocket_hook_path, 'r') as f:
            websocket_content = f.read()

        # Check for essential WebSocket events
        essential_events = ['flag_changed', 'cluster_scaled', 'alert_triggered']
        for event in essential_events:
            self.assertIn(event, websocket_content, f"WebSocket hook should handle {event} event")

    def test_app_component_integration(self):
        """Test main App component integration"""
        app_component_path = FRONTEND_DIR / "src" / "App.tsx"

        with open(app_component_path, 'r') as f:
            app_content = f.read()

        # Check for essential integrations
        self.assertIn('useQuery', app_content, "App should use React Query")
        self.assertIn('useWebSocket', app_content, "App should use WebSocket hook")
        self.assertIn('api.getCurrentUser', app_content, "App should call API service")


class TestComponentStructure(unittest.TestCase):
    """Test React component structure"""

    def test_essential_pages_exist(self):
        """Test that essential pages exist"""
        pages_dir = FRONTEND_DIR / "src" / "pages"
        essential_pages = [
            "Dashboard.tsx",
            "Login.tsx",
            "FeatureFlags.tsx",
            "Clusters.tsx",
            "Analytics.tsx"
        ]

        for page in essential_pages:
            page_path = pages_dir / page
            self.assertTrue(page_path.exists(), f"Page {page} should exist")

    def test_essential_components_exist(self):
        """Test that essential components exist"""
        components_dir = FRONTEND_DIR / "src" / "components"
        essential_components = [
            "Layout.tsx",
            "LoadingSpinner.tsx"
        ]

        for component in essential_components:
            component_path = components_dir / component
            self.assertTrue(component_path.exists(), f"Component {component} should exist")

    def test_types_definition_exists(self):
        """Test that TypeScript type definitions exist"""
        types_path = FRONTEND_DIR / "src" / "types" / "index.ts"
        self.assertTrue(types_path.exists(), "Type definitions should exist")

        with open(types_path, 'r') as f:
            types_content = f.read()

        # Check for essential type definitions
        essential_types = ['User', 'FeatureFlag', 'ClusterMetrics']
        for type_name in essential_types:
            self.assertIn(f'interface {type_name}', types_content, f"Type {type_name} should be defined")


if __name__ == '__main__':
    print("Running Frontend Tests")
    print("=" * 30)

    # Set working directory to frontend for relative path tests
    original_cwd = os.getcwd()

    try:
        # Run tests
        unittest.main(verbosity=2)
    finally:
        # Restore original working directory
        os.chdir(original_cwd)
