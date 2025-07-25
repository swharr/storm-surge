#!/bin/bash
# Test script to verify setup works with dummy values

echo "Testing LaunchDarkly setup with dummy values..."
echo -e "1\ntest-client-id-123\ntest-tracking-id-456\ny" | ./interactive-frontend-setup.sh

echo -e "\nChecking generated .env file..."
cat frontend/.env

echo -e "\n\nTesting Statsig setup with dummy values..."
echo -e "2\ntest-statsig-key-789\ny" | ./interactive-frontend-setup.sh

echo -e "\nChecking updated .env file..."
cat frontend/.env

echo -e "\n\nTesting command-line mode..."
./interactive-frontend-setup.sh --provider launchdarkly --client-id CHANGEME_LAUNCHDARKLY_CLIENT_ID_123456789 --tracking-id CHANGEME_TRACKING_ID_123456789

echo -e "\nChecking final .env file..."
cat frontend/.env