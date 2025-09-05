#!/bin/bash
set -e

echo "Storm Surge Dependency Verification Script"
echo "=========================================="

# Check if we're in the right directory
if [ ! -f "feature_flag_configure.py" ]; then
    echo "ERROR: Please run this script from the storm-surge root directory"
    exit 1
fi

echo "OK: Running from correct directory"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Python
echo -n "Python 3: "
if command_exists python3; then
    python3 --version
else
    echo "ERROR: Not found"
    exit 1
fi

# Check Node.js
echo -n "Node.js: "
if command_exists node; then
    node --version
else
    echo "ERROR: Not found"
fi

# Check npm
echo -n "npm: "
if command_exists npm; then
    npm --version
else
    echo "ERROR: Not found"
fi

# Check Docker
echo -n "Docker: "
if command_exists docker; then
    docker --version | head -1
else
    echo "WARN: Not found (optional for local development)"
fi

# Check kubectl
echo -n "kubectl: "
if command_exists kubectl; then
    kubectl version --client --short 2>/dev/null || (kubectl version --client 2>/dev/null | head -1)
else
    echo "WARN: Not found (needed for deployment)"
fi

echo ""
echo "Python Dependencies Check"
echo "========================="

# Check if requirements.txt exists
if [ -f "manifests/middleware/requirements.txt" ]; then
    echo "OK: Requirements file found"
    echo "Required packages:"
    grep -v "^#" manifests/middleware/requirements.txt | grep -v "^$" | while read -r package; do
        echo "  - $package"
    done
else
    echo "ERROR: Requirements file missing"
fi

echo ""
echo "React Dependencies Check"
echo "========================"

if [ -f "frontend/package.json" ]; then
    echo "OK: package.json found"

    if command_exists node; then
        echo "Package info:"
        node -e "
        const pkg = require('./frontend/package.json');
        console.log('  Name:', pkg.name);
        console.log('  Version:', pkg.version);
        console.log('  Dependencies:', Object.keys(pkg.dependencies || {}).length);
        console.log('  DevDependencies:', Object.keys(pkg.devDependencies || {}).length);
        "
    fi
else
    echo "ERROR: package.json missing"
fi

echo ""
echo "Configuration Files Check"
echo "========================="

config_files=(
    "frontend/tsconfig.json:TypeScript config"
    "frontend/tailwind.config.js:Tailwind CSS config"
    "frontend/vite.config.ts:Vite build config"
    "frontend/postcss.config.js:PostCSS config"
    "frontend/.eslintrc.cjs:ESLint config"
    "frontend/Dockerfile:Docker config"
    "frontend/nginx.conf:Nginx config"
)

for file_desc in "${config_files[@]}"; do
    file=$(echo "$file_desc" | cut -d: -f1)
    desc=$(echo "$file_desc" | cut -d: -f2)

    if [ -f "$file" ]; then
        echo "OK: $desc"
    else
        echo "ERROR: $desc missing ($file)"
    fi
done

echo ""
echo "Kubernetes Manifests Check"
echo "=========================="

k8s_files=(
    "manifests/middleware/deployment.yaml:Middleware deployment"
    "manifests/middleware/service.yaml:Middleware service"
    "manifests/middleware/configmap.yaml:Middleware config"
    "frontend/k8s/deployment.yaml:Frontend deployment"
    "frontend/k8s/service.yaml:Frontend service"
    "frontend/k8s/ingress.yaml:Frontend ingress"
)

for file_desc in "${k8s_files[@]}"; do
    file=$(echo "$file_desc" | cut -d: -f1)
    desc=$(echo "$file_desc" | cut -d: -f2)

    if [ -f "$file" ]; then
        echo "OK: $desc"
    else
        echo "ERROR: $desc missing ($file)"
    fi
done

echo ""
echo "Build Scripts Check"
echo "==================="

build_scripts=(
    "feature_flag_configure.py:Configuration script"
    "frontend/build-and-push.sh:Docker build script"
    "frontend/local-build.sh:Local build script"
)

for script_desc in "${build_scripts[@]}"; do
    script=$(echo "$script_desc" | cut -d: -f1)
    desc=$(echo "$script_desc" | cut -d: -f2)

    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo "OK: $desc (executable)"
        else
            echo "WARN: $desc (not executable)"
        fi
    else
        echo "ERROR: $desc missing ($script)"
    fi
done

echo ""
echo "Ready for Installation?"
echo "======================="

echo ""
echo "To install Python dependencies:"
echo "  cd manifests/middleware && pip install -r requirements.txt"
echo ""
echo "To install React dependencies:"
echo "  cd frontend && npm install"
echo ""
echo "To run the configuration:"
echo "  python3 feature_flag_configure.py"
echo ""
echo "Dependency verification complete."
