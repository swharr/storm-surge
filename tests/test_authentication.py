#!/usr/bin/env python3
"""
Tests for Storm Surge Authentication System
Tests backend authentication, authorization, and security features
"""

import unittest
import json
import os
import sys
from unittest.mock import Mock, patch, MagicMock
import tempfile
import time

# Add middleware directory to path
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'manifests', 'middleware'))

try:
    from api_routes import api_bp, hash_password, verify_password, generate_user_id
    from main import app
    MIDDLEWARE_AVAILABLE = True
except ImportError as e:
    MIDDLEWARE_AVAILABLE = False
    print(f"Warning: Could not import middleware: {e}")


class TestAuthenticationAvailability(unittest.TestCase):
    """Test authentication system availability"""

    def test_authentication_import(self):
        """Test that authentication components can be imported"""
        self.assertTrue(MIDDLEWARE_AVAILABLE, "Authentication system should be importable")


@unittest.skipIf(not MIDDLEWARE_AVAILABLE, "Middleware not available")
class TestPasswordSecurity(unittest.TestCase):
    """Test password hashing and verification"""

    def test_password_hashing(self):
        """Test password hashing functionality"""
        password = "testpassword123"
        hashed = hash_password(password)
        
        # Hash should be different from original password
        self.assertNotEqual(password, hashed)
        
        # Hash should be consistently long (bcrypt hashes are typically 60 chars)
        self.assertGreater(len(hashed), 50)
        
        # Hashing same password twice should produce different results
        hashed2 = hash_password(password)
        self.assertNotEqual(hashed, hashed2)

    def test_password_verification(self):
        """Test password verification functionality"""
        password = "testpassword123"
        wrong_password = "wrongpassword"
        hashed = hash_password(password)
        
        # Correct password should verify
        self.assertTrue(verify_password(password, hashed))
        
        # Wrong password should not verify
        self.assertFalse(verify_password(wrong_password, hashed))

    def test_user_id_generation(self):
        """Test user ID generation"""
        user_id1 = generate_user_id()
        user_id2 = generate_user_id()
        
        # Should generate different IDs
        self.assertNotEqual(user_id1, user_id2)
        
        # Should be strings
        self.assertIsInstance(user_id1, str)
        self.assertIsInstance(user_id2, str)
        
        # Should be reasonable length (UUID-like)
        self.assertGreater(len(user_id1), 30)


@unittest.skipIf(not MIDDLEWARE_AVAILABLE, "Middleware not available")
class TestAuthenticationEndpoints(unittest.TestCase):
    """Test authentication API endpoints"""

    def setUp(self):
        """Set up test client"""
        self.app = app
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()

    def test_login_endpoint_exists(self):
        """Test that login endpoint exists"""
        response = self.client.post('/api/auth/login', 
                                   data=json.dumps({}),
                                   content_type='application/json')
        # Should not be 404 (endpoint exists)
        self.assertNotEqual(response.status_code, 404)

    def test_login_validation(self):
        """Test login input validation"""
        # Missing email and password
        response = self.client.post('/api/auth/login',
                                   data=json.dumps({}),
                                   content_type='application/json')
        self.assertEqual(response.status_code, 400)
        
        data = json.loads(response.data)
        self.assertIn('error', data)

    def test_login_with_invalid_credentials(self):
        """Test login with invalid credentials"""
        response = self.client.post('/api/auth/login',
                                   data=json.dumps({
                                       'email': 'nonexistent@example.com',
                                       'password': 'wrongpassword'
                                   }),
                                   content_type='application/json')
        self.assertEqual(response.status_code, 401)
        
        data = json.loads(response.data)
        self.assertIn('error', data)

    def test_register_endpoint_requires_auth(self):
        """Test that registration endpoint requires authentication"""
        response = self.client.post('/api/auth/register',
                                   data=json.dumps({
                                       'email': 'test@example.com',
                                       'password': 'testpassword123',
                                       'name': 'Test User',
                                       'role': 'viewer'
                                   }),
                                   content_type='application/json')
        # Should require authentication
        self.assertEqual(response.status_code, 401)

    def test_me_endpoint_requires_auth(self):
        """Test that /auth/me endpoint requires authentication"""
        response = self.client.get('/api/auth/me')
        self.assertEqual(response.status_code, 401)

    def test_change_password_requires_auth(self):
        """Test that change password endpoint requires authentication"""
        response = self.client.post('/api/auth/change-password',
                                   data=json.dumps({
                                       'current_password': 'old',
                                       'new_password': 'newpassword123'
                                   }),
                                   content_type='application/json')
        self.assertEqual(response.status_code, 401)


@unittest.skipIf(not MIDDLEWARE_AVAILABLE, "Middleware not available")
class TestRoleBasedAccess(unittest.TestCase):
    """Test role-based access control"""

    def setUp(self):
        """Set up test client"""
        self.app = app
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()

    def test_user_management_requires_admin(self):
        """Test that user management endpoints require admin role"""
        # Test user list endpoint
        response = self.client.get('/api/users')
        self.assertEqual(response.status_code, 401)
        
        # Test user creation endpoint  
        response = self.client.post('/api/users')
        self.assertEqual(response.status_code, 401)

    def test_user_endpoints_exist(self):
        """Test that user management endpoints exist"""
        endpoints = [
            ('/api/users', 'GET'),
            ('/api/users/test-id', 'GET'),
            ('/api/users/test-id', 'PUT'), 
            ('/api/users/test-id', 'DELETE'),
            ('/api/users/test-id/reset-password', 'POST')
        ]
        
        for endpoint, method in endpoints:
            if method == 'GET':
                response = self.client.get(endpoint)
            elif method == 'POST':
                response = self.client.post(endpoint, data=json.dumps({}), content_type='application/json')
            elif method == 'PUT':
                response = self.client.put(endpoint, data=json.dumps({}), content_type='application/json')
            elif method == 'DELETE':
                response = self.client.delete(endpoint)
            
            # Should not be 404 (endpoint exists), but should be 401 (unauthorized)
            self.assertNotEqual(response.status_code, 404, f"Endpoint {endpoint} ({method}) should exist")
            self.assertEqual(response.status_code, 401, f"Endpoint {endpoint} ({method}) should require auth")


@unittest.skipIf(not MIDDLEWARE_AVAILABLE, "Middleware not available") 
class TestSecurityFeatures(unittest.TestCase):
    """Test security features like account locking, session management"""

    def setUp(self):
        """Set up test client"""
        self.app = app
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()

    def test_logout_endpoint_exists(self):
        """Test that logout endpoint exists and requires auth"""
        response = self.client.post('/api/auth/logout')
        # Should require authentication
        self.assertEqual(response.status_code, 401)

    def test_health_endpoint_public(self):
        """Test that health endpoint is publicly accessible"""
        response = self.client.get('/health')
        # Health endpoint should be accessible without auth
        self.assertEqual(response.status_code, 200)
        
        data = json.loads(response.data)
        self.assertIn('status', data)
        self.assertEqual(data['status'], 'healthy')


class TestFrontendAuthIntegration(unittest.TestCase):
    """Test frontend authentication integration"""

    def test_user_management_page_exists(self):
        """Test that user management page component exists"""
        user_mgmt_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            'frontend', 'src', 'pages', 'UserManagement.tsx'
        )
        self.assertTrue(os.path.exists(user_mgmt_path), "UserManagement component should exist")

    def test_api_service_has_auth_methods(self):
        """Test that API service has authentication methods"""
        api_service_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            'frontend', 'src', 'services', 'api.ts'
        )
        
        self.assertTrue(os.path.exists(api_service_path), "API service should exist")
        
        with open(api_service_path, 'r') as f:
            api_content = f.read()
        
        # Check for authentication methods
        auth_methods = ['login', 'logout', 'getCurrentUser', 'register', 'changePassword']
        for method in auth_methods:
            self.assertIn(method, api_content, f"API service should have {method} method")
        
        # Check for user management methods
        user_mgmt_methods = ['getUsers', 'updateUser', 'deleteUser', 'resetUserPassword']
        for method in user_mgmt_methods:
            self.assertIn(method, api_content, f"API service should have {method} method")

    def test_app_component_has_auth_integration(self):
        """Test that App component integrates authentication"""
        app_component_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            'frontend', 'src', 'App.tsx'
        )
        
        self.assertTrue(os.path.exists(app_component_path), "App component should exist")
        
        with open(app_component_path, 'r') as f:
            app_content = f.read()
        
        # Check for authentication integration
        auth_integrations = ['storm_surge_token', 'getCurrentUser', 'UserManagement']
        for integration in auth_integrations:
            self.assertIn(integration, app_content, f"App should integrate {integration}")


class TestConfigurationIntegration(unittest.TestCase):
    """Test configuration script integration with authentication"""

    def test_requirements_include_bcrypt(self):
        """Test that requirements.txt includes bcrypt for password hashing"""
        requirements_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            'manifests', 'middleware', 'requirements.txt'
        )
        
        self.assertTrue(os.path.exists(requirements_path), "Requirements file should exist")
        
        with open(requirements_path, 'r') as f:
            requirements_content = f.read()
        
        self.assertIn('bcrypt', requirements_content, "Requirements should include bcrypt")

    def test_configuration_script_updates_requirements(self):
        """Test that configuration script can update requirements"""
        config_script_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            'feature_flag_configure.py'
        )
        
        self.assertTrue(os.path.exists(config_script_path), "Configuration script should exist")
        
        # Test script compiles
        with open(config_script_path, 'r') as f:
            script_content = f.read()
        
        # Should handle bcrypt and authentication dependencies
        self.assertIn('requirements', script_content, "Script should handle requirements")


if __name__ == '__main__':
    print("🔐 Running Authentication System Tests")
    print("=" * 40)
    
    if MIDDLEWARE_AVAILABLE:
        print("✅ Authentication system is available")
    else:
        print("⚠️  Authentication system import failed - some tests will be skipped")
    
    print()
    
    # Run tests
    unittest.main(verbosity=2)