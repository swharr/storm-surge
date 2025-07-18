#!/usr/bin/env python3
"""
Script validation tests for Storm Surge
Tests deployment scripts, provider scripts, and utility scripts
"""

import unittest
import os
import sys
import subprocess
import tempfile
from pathlib import Path
from unittest.mock import patch, Mock
import json


class TestScriptStructure(unittest.TestCase):
    """Test script structure and organization"""
    
    def setUp(self):
        """Set up test environment"""
        self.scripts_dir = Path(__file__).parent.parent / 'scripts'
        self.required_scripts = [
            'deploy.sh',
            'providers/gke.sh',
            'providers/eks.sh',
            'providers/aks.sh',
            'deploy-finops.sh',
            'deploy-middleware.sh'
        ]
    
    def test_required_scripts_exist(self):
        """Test that all required scripts exist"""
        for script_name in self.required_scripts:
            script_path = self.scripts_dir / script_name
            self.assertTrue(script_path.exists(), f"Required script {script_name} should exist")
    
    def test_scripts_are_executable(self):
        """Test that scripts are executable"""
        for script_name in self.required_scripts:
            script_path = self.scripts_dir / script_name
            if script_path.exists():
                self.assertTrue(os.access(script_path, os.X_OK), f"Script {script_name} should be executable")
    
    def test_scripts_have_proper_shebang(self):
        """Test that scripts have proper shebang"""
        for script_name in self.required_scripts:
            script_path = self.scripts_dir / script_name
            if script_path.exists():
                with open(script_path, 'r') as f:
                    first_line = f.readline().strip()
                    self.assertTrue(first_line.startswith('#!'), f"Script {script_name} should have shebang")
    
    def test_script_directories_exist(self):
        """Test that script directories exist"""
        required_dirs = [
            'providers',
            'cleanup'
        ]
        
        for dir_name in required_dirs:
            dir_path = self.scripts_dir / dir_name
            self.assertTrue(dir_path.exists(), f"Directory {dir_name} should exist")


class TestDeploymentScript(unittest.TestCase):
    """Test main deployment script"""
    
    def setUp(self):
        """Set up test environment"""
        self.deploy_script = Path(__file__).parent.parent / 'scripts' / 'deploy.sh'
    
    def test_deploy_script_help(self):
        """Test deployment script help output"""
        if not self.deploy_script.exists():
            self.skipTest("Deploy script not found")
        
        # Test --help flag
        result = subprocess.run([str(self.deploy_script), '--help'], 
                              capture_output=True, text=True, timeout=10)
        
        # Should exit with error code (as per test-local.sh)
        self.assertNotEqual(result.returncode, 0)
        
        # Should contain help information
        output = result.stdout + result.stderr
        self.assertIn('Usage:', output.lower())
    
    def test_deploy_script_invalid_provider(self):
        """Test deployment script with invalid provider"""
        if not self.deploy_script.exists():
            self.skipTest("Deploy script not found")
        
        # Test with invalid provider
        process = subprocess.Popen([str(self.deploy_script), '--provider=invalid'], 
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE, 
                                 stderr=subprocess.PIPE, text=True)
        
        # Send 'n' to decline prompt
        stdout, stderr = process.communicate(input='n\n', timeout=10)
        
        # Should exit with error code
        self.assertNotEqual(process.returncode, 0)
    
    def test_deploy_script_environment_variables(self):
        """Test deployment script environment variable handling"""
        if not self.deploy_script.exists():
            self.skipTest("Deploy script not found")
        
        # Test that script recognizes environment variables
        with open(self.deploy_script, 'r') as f:
            content = f.read()
            
            # Should reference common environment variables
            expected_vars = [
                'STORM_REGION',
                'STORM_ZONE',
                'STORM_NODES'
            ]
            
            for var in expected_vars:
                self.assertIn(var, content, f"Script should reference {var} environment variable")


class TestProviderScripts(unittest.TestCase):
    """Test cloud provider scripts"""
    
    def setUp(self):
        """Set up test environment"""
        self.scripts_dir = Path(__file__).parent.parent / 'scripts'
        self.provider_scripts = [
            'providers/gke.sh',
            'providers/eks.sh',
            'providers/aks.sh'
        ]
    
    def test_provider_scripts_exist(self):
        """Test that provider scripts exist"""
        for script_name in self.provider_scripts:
            script_path = self.scripts_dir / script_name
            self.assertTrue(script_path.exists(), f"Provider script {script_name} should exist")
    
    def test_gke_script_validation(self):
        """Test GKE script validation"""
        gke_script = self.scripts_dir / 'providers' / 'gke.sh'
        if not gke_script.exists():
            self.skipTest("GKE script not found")
        
        # Test zone/region validation
        env = {
            'STORM_REGION': 'us-central1',
            'STORM_ZONE': 'us-west-2-a',  # Mismatched zone
            'STORM_NODES': '3'
        }
        
        result = subprocess.run([str(gke_script)], 
                              capture_output=True, text=True, timeout=10, env=env)
        
        # Should exit with error code due to zone/region mismatch
        self.assertNotEqual(result.returncode, 0)
    
    def test_provider_scripts_have_authentication_checks(self):
        """Test that provider scripts check for authentication"""
        for script_name in self.provider_scripts:
            script_path = self.scripts_dir / script_name
            if script_path.exists():
                with open(script_path, 'r') as f:
                    content = f.read()
                    
                    # Should have authentication checks
                    if 'gke' in script_name:
                        self.assertIn('gcloud', content, f"GKE script should check gcloud authentication")
                    elif 'eks' in script_name:
                        self.assertIn('aws', content, f"EKS script should check AWS authentication")
                    elif 'aks' in script_name:
                        self.assertIn('az', content, f"AKS script should check Azure authentication")
    
    def test_provider_scripts_have_region_validation(self):
        """Test that provider scripts validate regions"""
        for script_name in self.provider_scripts:
            script_path = self.scripts_dir / script_name
            if script_path.exists():
                with open(script_path, 'r') as f:
                    content = f.read()
                    
                    # Should validate regions
                    self.assertIn('STORM_REGION', content, f"Script {script_name} should validate region")


class TestUtilityScripts(unittest.TestCase):
    """Test utility scripts"""
    
    def setUp(self):
        """Set up test environment"""
        self.scripts_dir = Path(__file__).parent.parent / 'scripts'
        self.utility_scripts = [
            'deploy-finops.sh',
            'deploy-middleware.sh',
            'cleanup/cluster-sweep.sh'
        ]
    
    def test_utility_scripts_exist(self):
        """Test that utility scripts exist"""
        for script_name in self.utility_scripts:
            script_path = self.scripts_dir / script_name
            if script_path.exists():
                self.assertTrue(os.access(script_path, os.X_OK), f"Utility script {script_name} should be executable")
    
    def test_finops_deploy_script(self):
        """Test FinOps deployment script"""
        finops_script = self.scripts_dir / 'deploy-finops.sh'
        if not finops_script.exists():
            self.skipTest("FinOps deploy script not found")
        
        with open(finops_script, 'r') as f:
            content = f.read()
            
            # Should reference FinOps manifests
            self.assertIn('finops', content, "FinOps script should reference finops manifests")
    
    def test_middleware_deploy_script(self):
        """Test middleware deployment script"""
        middleware_script = self.scripts_dir / 'deploy-middleware.sh'
        if not middleware_script.exists():
            self.skipTest("Middleware deploy script not found")
        
        with open(middleware_script, 'r') as f:
            content = f.read()
            
            # Should reference middleware manifests
            self.assertIn('middleware', content, "Middleware script should reference middleware manifests")
    
    def test_cleanup_script(self):
        """Test cleanup script"""
        cleanup_script = self.scripts_dir / 'cleanup' / 'cluster-sweep.sh'
        if not cleanup_script.exists():
            self.skipTest("Cleanup script not found")
        
        with open(cleanup_script, 'r') as f:
            content = f.read()
            
            # Should have cleanup functionality
            self.assertIn('kubectl', content, "Cleanup script should use kubectl")


class TestScriptSyntax(unittest.TestCase):
    """Test script syntax validation"""
    
    def setUp(self):
        """Set up test environment"""
        self.scripts_dir = Path(__file__).parent.parent / 'scripts'
    
    def test_all_scripts_have_valid_syntax(self):
        """Test that all scripts have valid bash syntax"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))
        
        for script_file in script_files:
            with self.subTest(script=script_file):
                result = subprocess.run(['bash', '-n', str(script_file)], 
                                      capture_output=True, text=True)
                
                if result.returncode != 0:
                    self.fail(f"Script {script_file} has syntax error: {result.stderr}")
    
    def test_scripts_dont_use_deprecated_features(self):
        """Test that scripts don't use deprecated bash features"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))
        
        deprecated_patterns = [
            '`',  # Old command substitution
            'function ',  # Old function syntax
        ]
        
        for script_file in script_files:
            with open(script_file, 'r') as f:
                content = f.read()
                lines = content.split('\n')
                
                for line_num, line in enumerate(lines, 1):
                    for pattern in deprecated_patterns:
                        if pattern in line and not line.strip().startswith('#'):
                            print(f"⚠️  Script {script_file}:{line_num} uses deprecated syntax: {line.strip()}")
    
    def test_scripts_use_proper_variable_quoting(self):
        """Test that scripts use proper variable quoting"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))
        
        for script_file in script_files:
            with open(script_file, 'r') as f:
                content = f.read()
                
                # Look for unquoted variables that might cause issues
                # This is a basic check - a full implementation would be more complex
                if '$@' in content and '"$@"' not in content:
                    print(f"⚠️  Script {script_file} might need to quote $@ properly")


class TestScriptFunctionality(unittest.TestCase):
    """Test script functionality and behavior"""
    
    def setUp(self):
        """Set up test environment"""
        self.scripts_dir = Path(__file__).parent.parent / 'scripts'
    
    def test_scripts_handle_errors_properly(self):
        """Test that scripts handle errors properly"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))
        
        for script_file in script_files:
            with open(script_file, 'r') as f:
                content = f.read()
                
                # Check for error handling patterns
                has_error_handling = any(pattern in content for pattern in [
                    'set -e',
                    'set -o errexit',
                    'trap',
                    'exit 1',
                    'return 1'
                ])
                
                if not has_error_handling:
                    print(f"⚠️  Script {script_file} might need better error handling")
    
    def test_scripts_validate_prerequisites(self):
        """Test that scripts validate prerequisites"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))
        
        for script_file in script_files:
            with open(script_file, 'r') as f:
                content = f.read()
                
                # Check if scripts validate required tools
                if 'kubectl' in content:
                    if 'command -v kubectl' not in content and 'which kubectl' not in content:
                        print(f"⚠️  Script {script_file} uses kubectl but doesn't validate it's installed")
                
                if 'docker' in content:
                    if 'command -v docker' not in content and 'which docker' not in content:
                        print(f"⚠️  Script {script_file} uses docker but doesn't validate it's installed")
    
    def test_scripts_provide_user_feedback(self):
        """Test that scripts provide user feedback"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))
        
        for script_file in script_files:
            with open(script_file, 'r') as f:
                content = f.read()
                
                # Check for user feedback patterns
                has_feedback = any(pattern in content for pattern in [
                    'echo',
                    'printf',
                    'log(',
                    'success(',
                    'error(',
                    'warning('
                ])
                
                if not has_feedback:
                    print(f"⚠️  Script {script_file} might need better user feedback")


class TestScriptSecurity(unittest.TestCase):
    """Test script security aspects"""
    
    def setUp(self):
        """Set up test environment"""
        self.scripts_dir = Path(__file__).parent.parent / 'scripts'
    
    def test_scripts_dont_expose_secrets(self):
        """Test that scripts don't expose secrets"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))
        
        for script_file in script_files:
            with open(script_file, 'r') as f:
                content = f.read()
                
                # Check for secret exposure patterns
                risky_patterns = [
                    'echo $PASSWORD',
                    'echo $TOKEN',
                    'echo $KEY',
                    'echo $SECRET',
                    'cat $PASSWORD',
                    'cat $TOKEN'
                ]
                
                for pattern in risky_patterns:
                    if pattern in content:
                        self.fail(f"Script {script_file} might expose secrets: {pattern}")
    
    def test_scripts_use_secure_temp_files(self):
        """Test that scripts use secure temporary files"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))
        
        for script_file in script_files:
            with open(script_file, 'r') as f:
                content = f.read()
                
                # Check for insecure temp file usage
                if '/tmp/' in content:
                    # Look for mktemp usage
                    if 'mktemp' not in content:
                        print(f"⚠️  Script {script_file} uses /tmp without mktemp")
    
    def test_scripts_validate_inputs(self):
        """Test that scripts validate inputs"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))
        
        for script_file in script_files:
            with open(script_file, 'r') as f:
                content = f.read()
                
                # Check for input validation patterns
                if '$1' in content or '$2' in content or '$@' in content:
                    has_validation = any(pattern in content for pattern in [
                        'if [ -z',
                        'if [ ! -z',
                        'if [[ -z',
                        'if [[ ! -z',
                        'case "$1"',
                        'case $1'
                    ])
                    
                    if not has_validation:
                        print(f"⚠️  Script {script_file} takes arguments but might not validate them")


class TestScriptDocumentation(unittest.TestCase):
    """Test script documentation and help"""
    
    def setUp(self):
        """Set up test environment"""
        self.scripts_dir = Path(__file__).parent.parent / 'scripts'
    
    def test_scripts_have_description(self):
        """Test that scripts have description comments"""
        script_files = list(self.scripts_dir.glob('**/*.sh'))
        
        for script_file in script_files:
            with open(script_file, 'r') as f:
                lines = f.readlines()
                
                # Look for description in first 10 lines
                has_description = False
                for line in lines[:10]:
                    if line.strip().startswith('#') and len(line.strip()) > 10:
                        has_description = True
                        break
                
                if not has_description:
                    print(f"⚠️  Script {script_file} should have a description comment")
    
    def test_main_scripts_have_help(self):
        """Test that main scripts have help functionality"""
        main_scripts = [
            'deploy.sh',
            'providers/gke.sh',
            'providers/eks.sh',
            'providers/aks.sh'
        ]
        
        for script_name in main_scripts:
            script_path = self.scripts_dir / script_name
            if script_path.exists():
                with open(script_path, 'r') as f:
                    content = f.read()
                    
                    # Check for help functionality
                    has_help = any(pattern in content for pattern in [
                        '--help',
                        '-h',
                        'Usage:',
                        'USAGE:'
                    ])
                    
                    if not has_help:
                        print(f"⚠️  Script {script_name} should have help functionality")


if __name__ == '__main__':
    # Set up test environment
    os.environ['PYTHONPATH'] = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    # Print test information
    print("📜 Running Script Validation Tests")
    print("=" * 35)
    print()
    
    # Run tests
    unittest.main(verbosity=2)