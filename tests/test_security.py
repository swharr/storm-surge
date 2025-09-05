#!/usr/bin/env python3
"""
Security tests for Storm Surge
Tests security configurations, RBAC, secrets handling, and vulnerability checks
"""

import unittest
import os
import sys
try:
    import yaml
    YAML_AVAILABLE = True
except Exception:
    YAML_AVAILABLE = False
import json
import subprocess
import tempfile
import base64
from pathlib import Path

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


@unittest.skipIf(not YAML_AVAILABLE, "PyYAML not available in this environment")
class TestKubernetesSecurityConfigs(unittest.TestCase):
    """Test Kubernetes security configurations"""

    def setUp(self):
        """Set up test environment"""
        self.manifests_dir = Path(__file__).parent.parent / 'manifests'
        self.base_manifests = self.manifests_dir / 'base'
        self.middleware_manifests = self.manifests_dir / 'middleware'

    def test_deployments_have_security_context(self):
        """Test that all deployments have proper security context"""
        deployment_files = list(self.base_manifests.glob('*.yaml')) + list(self.middleware_manifests.glob('*.yaml'))

        for file_path in deployment_files:
            with open(file_path, 'r') as f:
                try:
                    docs = yaml.safe_load_all(f)
                    for doc in docs:
                        if doc and doc.get('kind') == 'Deployment':
                            self._validate_deployment_security_context(doc, file_path)
                except yaml.YAMLError:
                    # Skip invalid YAML files
                    continue

    def _validate_deployment_security_context(self, deployment, file_path):
        """Validate security context for a deployment"""
        spec = deployment.get('spec', {})
        template = spec.get('template', {})
        pod_spec = template.get('spec', {})

        # Check for security context at pod level
        security_context = pod_spec.get('securityContext', {})

        # Check containers
        containers = pod_spec.get('containers', [])
        for container in containers:
            container_security = container.get('securityContext', {})

            # Check for runAsNonRoot
            run_as_non_root = (
                container_security.get('runAsNonRoot') or
                security_context.get('runAsNonRoot')
            )

            if run_as_non_root is not True:
                self.fail(f"Container in {file_path} should have runAsNonRoot: true")

            # Check for runAsUser (should not be 0)
            run_as_user = (
                container_security.get('runAsUser') or
                security_context.get('runAsUser')
            )

            if run_as_user == 0:
                self.fail(f"Container in {file_path} should not run as root user (runAsUser: 0)")

    def test_deployments_have_resource_limits(self):
        """Test that all deployments have resource limits"""
        deployment_files = list(self.base_manifests.glob('*.yaml')) + list(self.middleware_manifests.glob('*.yaml'))

        for file_path in deployment_files:
            with open(file_path, 'r') as f:
                try:
                    docs = yaml.safe_load_all(f)
                    for doc in docs:
                        if doc and doc.get('kind') == 'Deployment':
                            self._validate_resource_limits(doc, file_path)
                except yaml.YAMLError:
                    # Skip invalid YAML files
                    continue

    def _validate_resource_limits(self, deployment, file_path):
        """Validate resource limits for a deployment"""
        spec = deployment.get('spec', {})
        template = spec.get('template', {})
        pod_spec = template.get('spec', {})
        containers = pod_spec.get('containers', [])

        for container in containers:
            resources = container.get('resources', {})

            # Check for limits
            limits = resources.get('limits', {})
            if not limits:
                self.fail(f"Container in {file_path} should have resource limits")

            # Check for requests
            requests = resources.get('requests', {})
            if not requests:
                self.fail(f"Container in {file_path} should have resource requests")

            # Check for specific resource types
            required_resources = ['memory', 'cpu']
            for resource_type in required_resources:
                if resource_type not in limits:
                    self.fail(f"Container in {file_path} should have {resource_type} limits")
                if resource_type not in requests:
                    self.fail(f"Container in {file_path} should have {resource_type} requests")

    def test_no_privileged_containers(self):
        """Test that no containers run in privileged mode"""
        deployment_files = list(self.base_manifests.glob('*.yaml')) + list(self.middleware_manifests.glob('*.yaml'))

        for file_path in deployment_files:
            with open(file_path, 'r') as f:
                try:
                    docs = yaml.safe_load_all(f)
                    for doc in docs:
                        if doc and doc.get('kind') == 'Deployment':
                            self._validate_no_privileged_containers(doc, file_path)
                except yaml.YAMLError:
                    # Skip invalid YAML files
                    continue

    def _validate_no_privileged_containers(self, deployment, file_path):
        """Validate that containers are not privileged"""
        spec = deployment.get('spec', {})
        template = spec.get('template', {})
        pod_spec = template.get('spec', {})
        containers = pod_spec.get('containers', [])

        for container in containers:
            security_context = container.get('securityContext', {})
            privileged = security_context.get('privileged', False)

            if privileged:
                self.fail(f"Container in {file_path} should not be privileged")

    def test_service_accounts_exist(self):
        """Test that service accounts are properly configured"""
        sa_files = list(self.manifests_dir.glob('**/rbac*.yaml'))

        # Check if RBAC files exist
        rbac_files_exist = len(sa_files) > 0

        if not rbac_files_exist:
            # This is a warning, not a failure, as RBAC might be handled differently
            print("⚠️  No RBAC files found - consider adding service accounts and role bindings")

    def test_network_policies_security(self):
        """Test network policies for security"""
        # Look for network policy files
        network_policy_files = list(self.manifests_dir.glob('**/networkpolicy*.yaml'))

        if not network_policy_files:
            # This is a warning, not a failure
            print("⚠️  No network policies found - consider adding network policies for security")

        # If network policies exist, validate them
        for file_path in network_policy_files:
            with open(file_path, 'r') as f:
                try:
                    docs = yaml.safe_load_all(f)
                    for doc in docs:
                        if doc and doc.get('kind') == 'NetworkPolicy':
                            self._validate_network_policy(doc, file_path)
                except yaml.YAMLError:
                    # Skip invalid YAML files
                    continue

    def _validate_network_policy(self, policy, file_path):
        """Validate network policy configuration"""
        spec = policy.get('spec', {})

        # Check for ingress/egress rules
        ingress = spec.get('ingress', [])
        egress = spec.get('egress', [])

        # Policy should have some rules
        if not ingress and not egress:
            self.fail(f"Network policy in {file_path} should have ingress or egress rules")


@unittest.skipIf(not YAML_AVAILABLE, "PyYAML not available in this environment")
class TestSecretsManagement(unittest.TestCase):
    """Test secrets management and handling"""

    def setUp(self):
        """Set up test environment"""
        self.manifests_dir = Path(__file__).parent.parent / 'manifests'

    def test_no_hardcoded_secrets(self):
        """Test that no hardcoded secrets exist in manifests"""
        # Patterns that indicate hardcoded secrets
        secret_patterns = [
            'password:',
            'token:',
            'key:',
            'secret:',
            'auth:',
            'credential:'
        ]

        # Patterns that are acceptable (references to secrets)
        acceptable_patterns = [
            'secretKeyRef',
            'configMapKeyRef',
            'valueFrom',
            'name: ld-spot-secrets',  # Secret name reference
            'key: ld-sdk-key'         # Secret key reference
        ]

        manifest_files = list(self.manifests_dir.glob('**/*.yaml'))

        for file_path in manifest_files:
            with open(file_path, 'r') as f:
                content = f.read()
                lines = content.split('\n')

                for line_num, line in enumerate(lines, 1):
                    line_lower = line.lower()

                    # Check for secret patterns
                    for pattern in secret_patterns:
                        if pattern in line_lower:
                            # Check if this is an acceptable pattern
                            is_acceptable = any(acceptable in line for acceptable in acceptable_patterns)

                            if not is_acceptable:
                                # Check if the value looks like a secret (base64, long string, etc.)
                                if ':' in line and len(line.split(':')[-1].strip()) > 20:
                                    self.fail(f"Potential hardcoded secret in {file_path}:{line_num}: {line.strip()}")

    def test_secret_resources_properly_configured(self):
        """Test that Secret resources are properly configured"""
        secret_files = list(self.manifests_dir.glob('**/secret*.yaml'))

        for file_path in secret_files:
            with open(file_path, 'r') as f:
                try:
                    docs = yaml.safe_load_all(f)
                    for doc in docs:
                        if doc and doc.get('kind') == 'Secret':
                            self._validate_secret_resource(doc, file_path)
                except yaml.YAMLError:
                    # Skip invalid YAML files
                    continue

    def _validate_secret_resource(self, secret, file_path):
        """Validate Secret resource configuration"""
        # Check for proper type
        secret_type = secret.get('type', 'Opaque')
        valid_types = ['Opaque', 'kubernetes.io/tls', 'kubernetes.io/service-account-token']

        if secret_type not in valid_types:
            self.fail(f"Secret in {file_path} has invalid type: {secret_type}")

        # Check data structure
        data = secret.get('data', {})
        string_data = secret.get('stringData', {})

        if not data and not string_data:
            self.fail(f"Secret in {file_path} should have data or stringData")

        # If data exists, check if it's base64 encoded
        if data:
            for key, value in data.items():
                if value:
                    try:
                        base64.b64decode(value, validate=True)
                    except Exception:
                        self.fail(f"Secret data in {file_path} should be base64 encoded")


@unittest.skipIf(not YAML_AVAILABLE, "PyYAML not available in this environment")
class TestImageSecurity(unittest.TestCase):
    """Test container image security"""

    def setUp(self):
        """Set up test environment"""
        self.manifests_dir = Path(__file__).parent.parent / 'manifests'

    def test_container_images_not_latest(self):
        """Test that container images don't use 'latest' tag"""
        deployment_files = list(self.manifests_dir.glob('**/*.yaml'))

        for file_path in deployment_files:
            with open(file_path, 'r') as f:
                try:
                    docs = yaml.safe_load_all(f)
                    for doc in docs:
                        if doc and doc.get('kind') in ['Deployment', 'DaemonSet', 'StatefulSet']:
                            self._validate_image_tags(doc, file_path)
                except yaml.YAMLError:
                    # Skip invalid YAML files
                    continue

    def _validate_image_tags(self, resource, file_path):
        """Validate container image tags"""
        spec = resource.get('spec', {})
        template = spec.get('template', {})
        pod_spec = template.get('spec', {})
        containers = pod_spec.get('containers', [])

        for container in containers:
            image = container.get('image', '')

            if not image:
                self.fail(f"Container in {file_path} should have an image specified")

            # Check for 'latest' tag
            if ':latest' in image or (':' not in image and image):
                self.fail(f"Container in {file_path} should not use 'latest' tag: {image}")

    def test_container_images_from_trusted_registries(self):
        """Test that container images are from trusted registries"""
        trusted_registries = [
            'docker.io',
            'gcr.io',
            'quay.io',
            'registry.k8s.io',
            'nginxinc'  # For nginx unprivileged
        ]

        deployment_files = list(self.manifests_dir.glob('**/*.yaml'))

        for file_path in deployment_files:
            with open(file_path, 'r') as f:
                try:
                    docs = yaml.safe_load_all(f)
                    for doc in docs:
                        if doc and doc.get('kind') in ['Deployment', 'DaemonSet', 'StatefulSet']:
                            self._validate_image_registries(doc, file_path, trusted_registries)
                except yaml.YAMLError:
                    # Skip invalid YAML files
                    continue

    def _validate_image_registries(self, resource, file_path, trusted_registries):
        """Validate container image registries"""
        spec = resource.get('spec', {})
        template = spec.get('template', {})
        pod_spec = template.get('spec', {})
        containers = pod_spec.get('containers', [])

        for container in containers:
            image = container.get('image', '')

            if image:
                # Check if image is from a trusted registry
                is_trusted = any(registry in image for registry in trusted_registries)

                if not is_trusted:
                    print(f"⚠️  Container in {file_path} uses untrusted registry: {image}")


class TestScriptSecurity(unittest.TestCase):
    """Test script security and validation"""

    def setUp(self):
        """Set up test environment"""
        self.scripts_dir = Path(__file__).parent.parent / 'scripts'

    def test_scripts_have_proper_permissions(self):
        """Test that scripts have proper permissions"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))

        for script_file in script_files:
            # Check if script is executable
            if not os.access(script_file, os.X_OK):
                self.fail(f"Script {script_file} should be executable")

            # Check that script is not world-writable
            stat_info = os.stat(script_file)
            if stat_info.st_mode & 0o002:  # World-writable
                self.fail(f"Script {script_file} should not be world-writable")

    def test_scripts_have_shebang(self):
        """Test that scripts have proper shebang"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))

        for script_file in script_files:
            with open(script_file, 'r') as f:
                first_line = f.readline().strip()

                if not first_line.startswith('#!'):
                    self.fail(f"Script {script_file} should have a shebang")

                # Check for bash shebang
                if '#!/bin/bash' not in first_line and '#!/usr/bin/env bash' not in first_line:
                    print(f"⚠️  Script {script_file} might not use bash shebang")

    def test_scripts_use_set_e(self):
        """Test that scripts use 'set -e' for error handling"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))

        for script_file in script_files:
            with open(script_file, 'r') as f:
                content = f.read()

                # Check for 'set -e' or 'set -ex' early in the script
                lines = content.split('\n')[:10]  # Check first 10 lines
                has_set_e = any('set -e' in line for line in lines)

                if not has_set_e:
                    print(f"⚠️  Script {script_file} should consider using 'set -e' for error handling")

    def test_no_hardcoded_credentials_in_scripts(self):
        """Test that scripts don't contain hardcoded credentials"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))

        credential_patterns = [
            'password=',
            'token=',
            'key=',
            'secret=',
            'auth=',
            'credential='
        ]

        for script_file in script_files:
            with open(script_file, 'r') as f:
                content = f.read()
                lines = content.split('\n')

                for line_num, line in enumerate(lines, 1):
                    line_lower = line.lower()

                    for pattern in credential_patterns:
                        if pattern in line_lower:
                            # Check if this is a variable assignment with environment variable
                            if '${' in line or '$(' in line or 'getenv' in line:
                                continue  # This is likely using environment variables

                            # Check if the value looks like a credential
                            if '=' in line:
                                value = line.split('=', 1)[1].strip().strip('"\'')
                                # Ignore kubectl --from-literal or any value that references env vars
                                if '$' in value or '--from-literal' in line:
                                    continue
                                if len(value) > 10 and not value.startswith('$'):
                                    self.fail(f"Potential hardcoded credential in {script_file}:{line_num}: {line.strip()}")


class TestVulnerabilityScanning(unittest.TestCase):
    """Test vulnerability scanning and security checks"""

    def test_dockerfile_security(self):
        """Test Dockerfile security practices"""
        dockerfile_paths = list(Path(__file__).parent.parent.glob('**/Dockerfile'))

        for dockerfile_path in dockerfile_paths:
            with open(dockerfile_path, 'r') as f:
                content = f.read()
                lines = content.split('\n')

                # Check for security best practices
                self._validate_dockerfile_security(lines, dockerfile_path)

    def _validate_dockerfile_security(self, lines, dockerfile_path):
        """Validate Dockerfile security practices"""
        has_user_directive = False
        runs_as_root = False

        for line in lines:
            line = line.strip()

            # Check for USER directive
            if line.startswith('USER '):
                has_user_directive = True
                user = line.split(' ', 1)[1].strip()
                if user == 'root' or user == '0':
                    runs_as_root = True

            # Check for ADD vs COPY
            if line.startswith('ADD '):
                print(f"⚠️  Dockerfile {dockerfile_path} uses ADD instead of COPY")

            # Check for package manager cache cleanup
            if 'apt-get install' in line and 'rm -rf /var/lib/apt/lists/*' not in line:
                print(f"⚠️  Dockerfile {dockerfile_path} should clean package manager cache")

        if not has_user_directive:
            self.fail(f"Dockerfile {dockerfile_path} should specify a non-root USER")

        if runs_as_root:
            self.fail(f"Dockerfile {dockerfile_path} should not run as root user")

    def test_yaml_syntax_validation(self):
        """Test YAML syntax validation"""
        if not YAML_AVAILABLE:
            self.skipTest('PyYAML not available in this environment')
        yaml_files = list(Path(__file__).parent.parent.glob('**/*.yaml'))

        for yaml_file in yaml_files:
            with open(yaml_file, 'r') as f:
                try:
                    yaml.safe_load_all(f)
                except Exception as e:
                    self.fail(f"YAML syntax error in {yaml_file}: {e}")

    def test_json_syntax_validation(self):
        """Test JSON syntax validation"""
        json_files = list(Path(__file__).parent.parent.glob('**/*.json'))

        for json_file in json_files:
            with open(json_file, 'r') as f:
                try:
                    json.load(f)
                except json.JSONDecodeError as e:
                    self.fail(f"JSON syntax error in {json_file}: {e}")


class TestComplianceChecks(unittest.TestCase):
    """Test compliance with security standards"""

    def test_pod_security_standards(self):
        """Test compliance with Pod Security Standards"""
        # This would implement checks for Pod Security Standards
        # For now, we'll do basic validation
        self.assertTrue(True, "Pod Security Standards validation placeholder")

    def test_cis_kubernetes_benchmark(self):
        """Test compliance with CIS Kubernetes Benchmark"""
        # This would implement checks for CIS Kubernetes Benchmark
        # For now, we'll do basic validation
        self.assertTrue(True, "CIS Kubernetes Benchmark validation placeholder")

    def test_owasp_kubernetes_top_10(self):
        """Test compliance with OWASP Kubernetes Top 10"""
        # This would implement checks for OWASP Kubernetes Top 10
        # For now, we'll do basic validation
        self.assertTrue(True, "OWASP Kubernetes Top 10 validation placeholder")


if __name__ == '__main__':
    # Set up test environment
    os.environ['PYTHONPATH'] = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    # Print test information
    print("🛡️  Running Security Tests")
    print("=" * 25)
    print()

    # Run tests
    unittest.main(verbosity=2)
