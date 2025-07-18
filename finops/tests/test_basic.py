#!/usr/bin/env python3
"""
Basic tests for FinOps Controller (no external dependencies)
"""

import unittest
import os
import sys
from unittest.mock import Mock, patch

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from finops_controller import StormSurgeFinOpsController
    CONTROLLER_AVAILABLE = True
except ImportError as e:
    CONTROLLER_AVAILABLE = False
    print(f"Warning: Could not import finops_controller: {e}")


class TestBasicFinOpsController(unittest.TestCase):
    """Basic test cases for FinOps Controller"""

    def setUp(self):
        """Set up test fixtures"""
        if CONTROLLER_AVAILABLE:
            self.controller = StormSurgeFinOpsController()
        else:
            self.skipTest("FinOps controller not available")

    def test_controller_exists(self):
        """Test that controller class exists"""
        self.assertTrue(CONTROLLER_AVAILABLE, "Controller should be importable")

    def test_controller_initialization(self):
        """Test that controller initializes correctly"""
        if CONTROLLER_AVAILABLE:
            self.assertIsNotNone(self.controller)
            self.assertTrue(hasattr(self.controller, 'logger'))

    def test_controller_methods_exist(self):
        """Test that required methods exist"""
        if CONTROLLER_AVAILABLE:
            self.assertTrue(hasattr(self.controller, 'disable_autoscaling_after_hours'))
            self.assertTrue(hasattr(self.controller, 'enable_autoscaling_business_hours'))
            self.assertTrue(callable(self.controller.disable_autoscaling_after_hours))
            self.assertTrue(callable(self.controller.enable_autoscaling_business_hours))

    def test_method_return_types(self):
        """Test that methods return expected types"""
        if CONTROLLER_AVAILABLE:
            result1 = self.controller.disable_autoscaling_after_hours()
            result2 = self.controller.enable_autoscaling_business_hours()
            
            self.assertIsInstance(result1, dict)
            self.assertIsInstance(result2, dict)
            
            # Check that status key exists
            self.assertIn("status", result1)
            self.assertIn("status", result2)

    def test_enable_autoscaling_returns_enabled(self):
        """Test that enable_autoscaling returns correct status"""
        if CONTROLLER_AVAILABLE:
            result = self.controller.enable_autoscaling_business_hours()
            self.assertEqual(result["status"], "enabled")

    def test_file_structure(self):
        """Test that required files exist"""
        finops_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        # Check main files exist
        self.assertTrue(os.path.exists(os.path.join(finops_dir, 'finops_controller.py')))
        self.assertTrue(os.path.exists(os.path.join(finops_dir, 'requirements.txt')))
        
        # Check tests directory exists
        tests_dir = os.path.join(finops_dir, 'tests')
        self.assertTrue(os.path.exists(tests_dir))
        self.assertTrue(os.path.exists(os.path.join(tests_dir, '__init__.py')))

    def test_environment_variable_access(self):
        """Test environment variable access"""
        # Test that environment variables can be accessed
        test_var = os.getenv('TEST_VAR', 'default_value')
        self.assertEqual(test_var, 'default_value')
        
        # Test with environment variable set
        with patch.dict(os.environ, {'TEST_VAR': 'test_value'}):
            test_var = os.getenv('TEST_VAR')
            self.assertEqual(test_var, 'test_value')


class TestFinOpsControllerStructure(unittest.TestCase):
    """Test the structure and organization of the FinOps controller"""

    def test_project_structure(self):
        """Test that project has correct structure"""
        finops_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        # Expected files
        expected_files = [
            'finops_controller.py',
            'requirements.txt',
            'tests/__init__.py',
            'tests/test_basic.py',
            'tests/test_finops_controller.py',
            'tests/test_integration.py',
            'tests/conftest.py',
            'tests/requirements.txt',
            'tests/run_tests.sh'
        ]
        
        for file_path in expected_files:
            full_path = os.path.join(finops_dir, file_path)
            self.assertTrue(os.path.exists(full_path), f"File {file_path} should exist")

    def test_test_files_executable(self):
        """Test that test runner is executable"""
        finops_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        test_runner = os.path.join(finops_dir, 'tests', 'run_tests.sh')
        
        # Check file exists
        self.assertTrue(os.path.exists(test_runner))
        
        # Check file is executable
        self.assertTrue(os.access(test_runner, os.X_OK))

    def test_requirements_files_exist(self):
        """Test that requirements files exist"""
        finops_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        # Main requirements
        main_requirements = os.path.join(finops_dir, 'requirements.txt')
        self.assertTrue(os.path.exists(main_requirements))
        
        # Test requirements
        test_requirements = os.path.join(finops_dir, 'tests', 'requirements.txt')
        self.assertTrue(os.path.exists(test_requirements))

    def test_python_import_paths(self):
        """Test that Python import paths are correct"""
        finops_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        # Test that we can construct the correct import path
        expected_path = os.path.join(finops_dir, 'finops_controller.py')
        self.assertTrue(os.path.exists(expected_path))
        
        # Test that the path is in sys.path after our setup
        self.assertIn(finops_dir, sys.path)


if __name__ == '__main__':
    # Print test information
    print("🧪 Running Basic FinOps Controller Tests")
    print("=" * 40)
    
    if CONTROLLER_AVAILABLE:
        print("✅ FinOps Controller is available")
    else:
        print("⚠️  FinOps Controller import failed - some tests will be skipped")
    
    print()
    
    # Run tests
    unittest.main(verbosity=2)
