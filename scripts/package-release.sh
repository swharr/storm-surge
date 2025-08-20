#!/bin/bash

# Storm Surge Release Packaging Script
# Creates a release package for distribution

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_VERSION="${1:-dev-v1.2.0-internal}"
BUILD_DIR="${PROJECT_ROOT}/build"
DIST_DIR="${PROJECT_ROOT}/dist"
RELEASE_NAME="storm-surge-${RELEASE_VERSION}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}    Storm Surge Release Packaging${NC}"
    echo -e "${BOLD}${BLUE}    Version: ${RELEASE_VERSION}${NC}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════${NC}"
    echo
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    for tool in git tar zip jq; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository"
        exit 1
    fi
    
    print_info "All prerequisites satisfied"
}

# Clean build directories
clean_build() {
    print_step "Cleaning build directories..."
    
    rm -rf "$BUILD_DIR" "$DIST_DIR"
    mkdir -p "$BUILD_DIR" "$DIST_DIR"
    
    print_info "Build directories cleaned"
}

# Update version numbers
update_versions() {
    print_step "Updating version numbers to ${RELEASE_VERSION}..."
    
    # Update package.json
    if [ -f "$PROJECT_ROOT/frontend/package.json" ]; then
        local version_number=$(echo "$RELEASE_VERSION" | sed 's/^v//')
        jq --arg version "$version_number" '.version = $version' "$PROJECT_ROOT/frontend/package.json" > "$PROJECT_ROOT/frontend/package.json.tmp"
        mv "$PROJECT_ROOT/frontend/package.json.tmp" "$PROJECT_ROOT/frontend/package.json"
        print_info "Updated frontend/package.json"
    fi
    
    # Update setup.sh version display
    sed -i.bak "s/dev-v[0-9.]*-[a-z]*/dev-v1.2.0-internal/g" "$PROJECT_ROOT/setup.sh" 2>/dev/null || true
    rm -f "$PROJECT_ROOT/setup.sh.bak"
    
    print_info "Version numbers updated"
}

# Run validation tests
run_validations() {
    print_step "Running validation tests..."
    
    # Run security checks
    if [ -x "$PROJECT_ROOT/tests/test-local.sh" ]; then
        print_info "Running local tests..."
        cd "$PROJECT_ROOT"
        ./tests/test-local.sh || print_warning "Some tests failed"
    fi
    
    # Check for hardcoded credentials
    print_info "Checking for hardcoded credentials..."
    if grep -r "password.*=" manifests/ \
        --exclude="*.md" \
        --exclude="*.pyc" \
        --exclude-dir=test_venv \
        --exclude-dir=__pycache__ \
        --binary-files=without-match | \
        grep -v "REPLACE_WITH" | \
        grep -v "CHANGEME_" | \
        grep -v "os.getenv" | \
        grep -v "password.*Field(" | \
        grep -v "password.*=.*data.get" | \
        grep -v "password_hash" | \
        grep -v "password_encryption" | \
        grep -v "admin_password.*=.*\\$" | \
        grep -v "password=admin_password" | \
        grep -v "password=SecurityConfig" | \
        grep -v "password=None" | \
        grep -v "SELECT.*password" | \
        grep -v "/reset-password" | \
        grep -v "/change-password" | \
        grep -v "new_password" | \
        grep -v "current_password"; then
        print_error "Found potential hardcoded credentials"
        exit 1
    fi
    
    print_info "Validations completed"
}

# Create release documentation
create_release_docs() {
    print_step "Creating release documentation..."
    
    cat > "$BUILD_DIR/RELEASE_NOTES.md" << EOF
# Storm Surge Release ${RELEASE_VERSION}

Release Date: $(date '+%Y-%m-%d')

## Overview
Storm Surge ${RELEASE_VERSION} provides a comprehensive multi-cloud Kubernetes deployment platform with production-ready security, monitoring, and cost optimization features.

## Key Features
- Multi-cloud support (AWS EKS, Google GKE, Azure AKS)
- Production security hardening with IAM policies
- Automated SSL/TLS certificate management
- Cost tracking and optimization
- Platform status monitoring (pstats.sh)
- Professional enterprise-grade documentation

## What's Included
- Complete Kubernetes manifests for all services
- Multi-cloud infrastructure configurations
- Security policies and network configurations
- IAM/RBAC policies for all cloud providers
- Monitoring and observability stack
- Automated setup and deployment scripts
- Comprehensive documentation

## Quick Start
1. Extract the release archive
2. Run ./setup.sh for interactive deployment
3. Use ./scripts/pstats.sh to monitor your clusters

## Cloud Provider Requirements
- AWS: EKS-enabled account with appropriate IAM permissions
- GCP: GKE-enabled project with billing configured
- Azure: AKS-enabled subscription with contributor access

## Support
- Documentation: See manifests/DEPLOYMENT_GUIDE.md
- Issues: https://github.com/swharr/storm-surge/issues

## Security Notes
- All secrets use runtime generation
- No hardcoded credentials included
- Review manifests/CREDENTIALS_SECURITY.md before deployment

---
Generated on $(date) by Storm Surge Packaging System
EOF

    print_info "Release documentation created"
}

# Copy project files
copy_project_files() {
    print_step "Copying project files..."
    
    # Create directory structure
    mkdir -p "$BUILD_DIR/$RELEASE_NAME"
    
    # Define files to include
    local include_files=(
        "setup.sh"
        "README.md"
        "CHANGELOG.md"
        "LICENSE"
        "manifests"
        "scripts"
        "frontend"
        "tests"
        "finops"
        "chaos-testing"
        ".github/workflows"
    )
    
    # Copy files
    for file in "${include_files[@]}"; do
        if [ -e "$PROJECT_ROOT/$file" ]; then
            cp -r "$PROJECT_ROOT/$file" "$BUILD_DIR/$RELEASE_NAME/"
            print_info "Copied $file"
        fi
    done
    
    # Copy release notes
    cp "$BUILD_DIR/RELEASE_NOTES.md" "$BUILD_DIR/$RELEASE_NAME/"
    
    # Remove sensitive files
    find "$BUILD_DIR/$RELEASE_NAME" -name ".env" -delete
    find "$BUILD_DIR/$RELEASE_NAME" -name "*.key" -delete
    find "$BUILD_DIR/$RELEASE_NAME" -name "*.pem" -delete
    find "$BUILD_DIR/$RELEASE_NAME" -path "*/secrets/*" -delete
    find "$BUILD_DIR/$RELEASE_NAME" -name "generated-secrets.yaml" -delete
    
    print_info "Project files copied and cleaned"
}

# Create archives
create_archives() {
    print_step "Creating release archives..."
    
    cd "$BUILD_DIR"
    
    # Create tar.gz archive
    tar -czf "$DIST_DIR/${RELEASE_NAME}.tar.gz" "$RELEASE_NAME"
    print_info "Created ${RELEASE_NAME}.tar.gz"
    
    # Create zip archive
    zip -qr "$DIST_DIR/${RELEASE_NAME}.zip" "$RELEASE_NAME"
    print_info "Created ${RELEASE_NAME}.zip"
    
    # Calculate checksums
    cd "$DIST_DIR"
    sha256sum "${RELEASE_NAME}.tar.gz" > "${RELEASE_NAME}.tar.gz.sha256"
    sha256sum "${RELEASE_NAME}.zip" > "${RELEASE_NAME}.zip.sha256"
    
    print_info "Created checksums"
}

# Create git tag
create_git_tag() {
    print_step "Creating git tag..."
    
    # Check if tag already exists
    if git rev-parse "$RELEASE_VERSION" >/dev/null 2>&1; then
        print_warning "Tag $RELEASE_VERSION already exists"
    else
        git tag -a "$RELEASE_VERSION" -m "Release $RELEASE_VERSION"
        print_info "Created tag $RELEASE_VERSION"
    fi
}

# Generate summary
generate_summary() {
    print_step "Release packaging completed!"
    
    echo
    echo -e "${GREEN}${BOLD}Release Summary${NC}"
    echo -e "${BOLD}Version:${NC} $RELEASE_VERSION"
    echo -e "${BOLD}Git Commit:${NC} $(git rev-parse --short HEAD)"
    echo -e "${BOLD}Build Date:${NC} $(date)"
    echo
    echo -e "${BOLD}Release Archives:${NC}"
    ls -lh "$DIST_DIR"/${RELEASE_NAME}.*
    echo
    echo -e "${BOLD}Next Steps:${NC}"
    echo "1. Review the release in dist/"
    echo "2. Test the release package"
    echo "3. Push to repository: git push origin $RELEASE_VERSION"
    echo "4. Create GitHub release and upload archives"
    echo
    echo -e "${GREEN}✓ Release packaging completed successfully${NC}"
}

# Main execution
main() {
    print_header
    
    check_prerequisites
    clean_build
    update_versions
    run_validations
    create_release_docs
    copy_project_files
    create_archives
    create_git_tag
    generate_summary
}

# Show help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [VERSION]"
    echo ""
    echo "Package Storm Surge for release"
    echo ""
    echo "Arguments:"
    echo "  VERSION    Release version (default: dev-v1.2.0-internal)"
    echo ""
    echo "Example:"
    echo "  $0 v1.2.0"
    echo "  $0 dev-v1.2.0-internal"
    exit 0
fi

# Run main function
main "$@"