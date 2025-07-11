#!/bin/bash
# Test runner for FinOps Controller

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Running FinOps Controller Tests${NC}"
echo "======================================="

# Check if we're in the right directory
if [ ! -f "../finops_controller.py" ]; then
    echo -e "${RED}❌ Error: Run this script from the finops/tests directory${NC}"
    exit 1
fi

# Install test requirements
echo -e "${YELLOW}📦 Installing test requirements...${NC}"
pip install -r requirements.txt

# Run unit tests
echo -e "${BLUE}🔧 Running unit tests...${NC}"
python -m pytest test_finops_controller.py -v

# Run integration tests  
echo -e "${BLUE}🔗 Running integration tests...${NC}"
python -m pytest test_integration.py -v

# Run with coverage
echo -e "${BLUE}📊 Running tests with coverage...${NC}"
python -m pytest --cov=../finops_controller --cov-report=html --cov-report=term

# Run specific test categories
echo -e "${BLUE}🏷️  Running API tests...${NC}"
python -m pytest -m api -v

echo -e "${BLUE}🔄 Running integration tests...${NC}"
python -m pytest -m integration -v

echo -e "${GREEN}✅ All tests completed!${NC}"
echo -e "${GREEN}📋 Coverage report generated in htmlcov/index.html${NC}"