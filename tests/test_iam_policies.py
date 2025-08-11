#!/usr/bin/env python3
"""
IAM Policy Validation Tests
Comprehensive tests for IAM policies across all cloud providers
"""

import json
import yaml
import os
import sys
import unittest
from pathlib import Path

# Get project root directory
PROJECT_ROOT = Path(__file__).parent.parent


class TestIAMPolicies(unittest.TestCase):
    """Test suite for IAM policy validation"""

    def setUp(self):
        """Set up test environment"""
        self.iam_dir = PROJECT_ROOT / "manifests" / "providerIAM"
        self.aws_policy = self.iam_dir / "aws" / "eks-admin-policy.json"
        self.gcp_role = self.iam_dir / "gcp" / "gke-admin-role.yaml"
        self.azure_role = self.iam_dir / "azure" / "aks-admin-role.json"

    def test_directory_structure(self):
        """Test that IAM directory structure is correct"""
        self.assertTrue(self.iam_dir.exists(), "providerIAM directory missing")
        
        # Check subdirectories
        for provider in ["aws", "gcp", "azure"]:
            provider_dir = self.iam_dir / provider
            self.assertTrue(provider_dir.exists(), f"{provider} directory missing")
            self.assertTrue(provider_dir.is_dir(), f"{provider} is not a directory")

    def test_aws_iam_policy(self):
        """Test AWS IAM policy structure and content"""
        self.assertTrue(self.aws_policy.exists(), "AWS policy file missing")
        
        # Load and validate JSON
        with open(self.aws_policy, 'r') as f:
            policy = json.load(f)
        
        # Check structure
        self.assertIn("Version", policy, "Policy missing Version")
        self.assertEqual(policy["Version"], "2012-10-17", "Invalid policy version")
        self.assertIn("Statement", policy, "Policy missing Statement")
        self.assertIsInstance(policy["Statement"], list, "Statement must be a list")
        self.assertGreater(len(policy["Statement"]), 0, "No statements in policy")
        
        # Check for required permission categories
        all_actions = []
        for statement in policy["Statement"]:
            self.assertIn("Effect", statement, "Statement missing Effect")
            self.assertIn("Action", statement, "Statement missing Action")
            self.assertIn("Resource", statement, "Statement missing Resource")
            
            if isinstance(statement["Action"], list):
                all_actions.extend(statement["Action"])
            else:
                all_actions.append(statement["Action"])
        
        # Verify critical EKS permissions
        eks_actions = [a for a in all_actions if a.startswith("eks:")]
        self.assertGreater(len(eks_actions), 0, "No EKS permissions found")
        
        critical_eks = ["eks:CreateCluster", "eks:DeleteCluster", "eks:UpdateClusterConfig"]
        for action in critical_eks:
            self.assertTrue(
                action in all_actions or "eks:*" in all_actions,
                f"Missing critical permission: {action}"
            )
        
        # Verify EC2 permissions
        ec2_actions = [a for a in all_actions if a.startswith("ec2:")]
        self.assertGreater(len(ec2_actions), 10, "Insufficient EC2 permissions")
        
        # Verify IAM permissions
        iam_actions = [a for a in all_actions if a.startswith("iam:")]
        self.assertGreater(len(iam_actions), 5, "Insufficient IAM permissions")
        
        # Verify other required services
        required_services = ["autoscaling:", "elasticloadbalancing:", "logs:", "kms:"]
        for service in required_services:
            service_actions = [a for a in all_actions if a.startswith(service)]
            self.assertGreater(len(service_actions), 0, f"No {service} permissions found")

    def test_gcp_iam_role(self):
        """Test GCP IAM role structure and content"""
        self.assertTrue(self.gcp_role.exists(), "GCP role file missing")
        
        # Load and validate YAML
        with open(self.gcp_role, 'r') as f:
            role = yaml.safe_load(f)
        
        # Check structure
        self.assertIn("title", role, "Role missing title")
        self.assertIn("description", role, "Role missing description")
        self.assertIn("includedPermissions", role, "Role missing includedPermissions")
        self.assertIsInstance(role["includedPermissions"], list, "Permissions must be a list")
        self.assertGreater(len(role["includedPermissions"]), 0, "No permissions in role")
        
        permissions = role["includedPermissions"]
        
        # Verify GKE permissions
        gke_perms = [p for p in permissions if p.startswith("container.")]
        self.assertGreater(len(gke_perms), 10, "Insufficient GKE permissions")
        
        critical_gke = [
            "container.clusters.create",
            "container.clusters.delete",
            "container.clusters.update",
            "container.clusters.get"
        ]
        for perm in critical_gke:
            self.assertIn(perm, permissions, f"Missing critical permission: {perm}")
        
        # Verify Compute permissions
        compute_perms = [p for p in permissions if p.startswith("compute.")]
        self.assertGreater(len(compute_perms), 20, "Insufficient Compute permissions")
        
        # Verify IAM permissions
        iam_perms = [p for p in permissions if p.startswith("iam.")]
        self.assertGreater(len(iam_perms), 5, "Insufficient IAM permissions")
        
        # Verify other required services
        required_prefixes = ["storage.", "logging.", "monitoring.", "cloudkms."]
        for prefix in required_prefixes:
            service_perms = [p for p in permissions if p.startswith(prefix)]
            self.assertGreater(len(service_perms), 0, f"No {prefix} permissions found")

    def test_azure_rbac_role(self):
        """Test Azure RBAC role structure and content"""
        self.assertTrue(self.azure_role.exists(), "Azure role file missing")
        
        # Load and validate JSON
        with open(self.azure_role, 'r') as f:
            role = json.load(f)
        
        # Check structure
        self.assertIn("Name", role, "Role missing Name")
        self.assertIn("Description", role, "Role missing Description")
        self.assertIn("Actions", role, "Role missing Actions")
        self.assertIsInstance(role["Actions"], list, "Actions must be a list")
        self.assertGreater(len(role["Actions"]), 0, "No actions in role")
        self.assertIn("AssignableScopes", role, "Role missing AssignableScopes")
        
        actions = role["Actions"]
        
        # Verify AKS permissions
        aks_actions = [a for a in actions if "ContainerService" in a]
        self.assertGreater(len(aks_actions), 0, "No AKS permissions found")
        self.assertIn("Microsoft.ContainerService/*", actions, "Missing full AKS permissions")
        
        # Verify Compute permissions
        compute_actions = [a for a in actions if "Microsoft.Compute" in a]
        self.assertGreater(len(compute_actions), 5, "Insufficient Compute permissions")
        
        # Verify Network permissions
        network_actions = [a for a in actions if "Microsoft.Network" in a]
        self.assertGreater(len(network_actions), 5, "Insufficient Network permissions")
        
        # Verify other required services
        required_services = [
            "Microsoft.Storage",
            "Microsoft.KeyVault",
            "Microsoft.ManagedIdentity",
            "Microsoft.Authorization"
        ]
        for service in required_services:
            service_actions = [a for a in actions if service in a]
            self.assertGreater(len(service_actions), 0, f"No {service} permissions found")

    def test_validation_script(self):
        """Test IAM validation script"""
        validation_script = self.iam_dir / "validate-permissions.sh"
        self.assertTrue(validation_script.exists(), "Validation script missing")
        self.assertTrue(os.access(validation_script, os.X_OK), "Validation script not executable")
        
        # Check script has required functions
        with open(validation_script, 'r') as f:
            content = f.read()
        
        required_functions = ["validate_aws", "validate_gcp", "validate_azure"]
        for func in required_functions:
            self.assertIn(f"{func}()", content, f"Missing function: {func}")

    def test_setup_scripts(self):
        """Test IAM setup scripts"""
        scripts_dir = PROJECT_ROOT / "scripts" / "iam"
        self.assertTrue(scripts_dir.exists(), "IAM scripts directory missing")
        
        for provider in ["aws", "gcp", "azure"]:
            script = scripts_dir / f"apply-{provider}-iam.sh"
            self.assertTrue(script.exists(), f"{provider} setup script missing")
            self.assertTrue(os.access(script, os.X_OK), f"{provider} script not executable")
            
            # Check script content
            with open(script, 'r') as f:
                content = f.read()
            
            # Verify script references correct policy files
            if provider == "aws":
                self.assertIn("eks-admin-policy.json", content, "AWS script missing policy reference")
            elif provider == "gcp":
                self.assertIn("gke-admin-role.yaml", content, "GCP script missing role reference")
            elif provider == "azure":
                self.assertIn("aks-admin-role.json", content, "Azure script missing role reference")

    def test_readme_documentation(self):
        """Test README files exist and contain required sections"""
        # Main README
        main_readme = self.iam_dir / "README.md"
        self.assertTrue(main_readme.exists(), "Main IAM README missing")
        
        with open(main_readme, 'r') as f:
            content = f.read()
        
        required_sections = ["Overview", "Directory Structure", "Quick Start", "Security"]
        for section in required_sections:
            self.assertIn(section, content, f"Main README missing section: {section}")
        
        # Provider-specific READMEs
        for provider in ["aws", "gcp", "azure"]:
            readme = self.iam_dir / provider / "README.md"
            self.assertTrue(readme.exists(), f"{provider} README missing")
            
            with open(readme, 'r') as f:
                content = f.read()
            
            # Check for required content
            self.assertIn("Usage", content, f"{provider} README missing Usage section")
            self.assertIn("Security", content, f"{provider} README missing Security section")
            
            # Check for provider-specific content
            if provider == "aws":
                self.assertIn("IAM", content, "AWS README should mention IAM")
                self.assertIn("EKS", content, "AWS README should mention EKS")
            elif provider == "gcp":
                self.assertIn("service account", content, "GCP README should mention service accounts")
                self.assertIn("GKE", content, "GCP README should mention GKE")
            elif provider == "azure":
                self.assertIn("RBAC", content, "Azure README should mention RBAC")
                self.assertIn("AKS", content, "Azure README should mention AKS")

    def test_no_hardcoded_credentials(self):
        """Ensure no hardcoded credentials in IAM files"""
        # List of patterns that might indicate hardcoded credentials
        suspicious_patterns = [
            "AKIA",  # AWS access key prefix
            "password:",
            "secret:",
            "key:",
            "token:"
        ]
        
        # Check all files in IAM directory
        for file_path in self.iam_dir.rglob("*"):
            if file_path.is_file() and file_path.suffix in [".json", ".yaml", ".yml", ".sh", ".md"]:
                with open(file_path, 'r') as f:
                    content = f.read().lower()
                
                for pattern in suspicious_patterns:
                    if pattern.lower() in content:
                        # Allow certain exceptions
                        if pattern == "key:" and ("api-key" in content or "access-key" in content):
                            continue
                        if pattern == "password:" and ("password=" in content or "password}" in content):
                            continue
                        if file_path.name == "README.md":
                            continue
                        
                        # Check if it's in a comment or example
                        lines = content.split('\n')
                        for i, line in enumerate(lines):
                            if pattern.lower() in line:
                                if not any(x in line for x in ['#', '//', 'example', 'your-', 'replace']):
                                    self.fail(f"Potential credential in {file_path} line {i+1}: {pattern}")


def main():
    """Run tests with detailed output"""
    # Create test suite
    suite = unittest.TestLoader().loadTestsFromTestCase(TestIAMPolicies)
    
    # Run tests with verbose output
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Exit with appropriate code
    sys.exit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    main()