#!/usr/bin/env bash
#
# Fix trailing whitespace in project files
# This script removes trailing whitespace from all text files in the project

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🧹 Fixing trailing whitespace in project files...${NC}"

# Function to check if file is binary
is_binary() {
    file --mime "$1" | grep -q "binary"
}

# Function to fix whitespace in a file
fix_file() {
    local file="$1"
    
    # Skip binary files
    if is_binary "$file"; then
        return 0
    fi
    
    # Skip specific directories
    case "$file" in
        */node_modules/*|*/.git/*|*/.npm/*|*/coverage/*|*/test-logs/*|*/__pycache__/*)
            return 0
            ;;
    esac
    
    # Check if file has trailing whitespace
    if grep -q '[[:space:]]$' "$file" 2>/dev/null; then
        echo -e "${YELLOW}  Fixing: $file${NC}"
        
        # Remove trailing whitespace based on OS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' 's/[[:space:]]*$//' "$file"
        else
            # Linux
            sed -i 's/[[:space:]]*$//' "$file"
        fi
        return 1
    fi
    return 0
}

# Counter for files fixed
fixed_count=0
checked_count=0

# Find all text files and fix them
echo -e "${GREEN}Scanning files...${NC}"

# Process Python files
for file in $(find . -name "*.py" -type f 2>/dev/null | grep -v -E "(node_modules|\.git|\.npm|coverage|test-logs|__pycache__)"); do
    ((checked_count++))
    if fix_file "$file"; then
        :
    else
        ((fixed_count++))
    fi
done

# Process YAML files
for file in $(find . -name "*.yaml" -o -name "*.yml" -type f 2>/dev/null | grep -v -E "(node_modules|\.git|\.npm|coverage|test-logs)"); do
    ((checked_count++))
    if fix_file "$file"; then
        :
    else
        ((fixed_count++))
    fi
done

# Process JSON files
for file in $(find . -name "*.json" -type f 2>/dev/null | grep -v -E "(node_modules|\.git|\.npm|coverage|test-logs)"); do
    ((checked_count++))
    if fix_file "$file"; then
        :
    else
        ((fixed_count++))
    fi
done

# Process shell scripts
for file in $(find . -name "*.sh" -type f 2>/dev/null | grep -v -E "(node_modules|\.git|\.npm|coverage|test-logs)"); do
    ((checked_count++))
    if fix_file "$file"; then
        :
    else
        ((fixed_count++))
    fi
done

# Process Markdown files (but preserve intentional trailing spaces for line breaks)
for file in $(find . -name "*.md" -type f 2>/dev/null | grep -v -E "(node_modules|\.git|\.npm|coverage|test-logs)"); do
    ((checked_count++))
    # For markdown, only remove trailing spaces if there are more than 2 spaces
    # (2 spaces at end of line is intentional for line breaks in markdown)
    if grep -q '[[:space:]]\{3,\}$' "$file" 2>/dev/null; then
        echo -e "${YELLOW}  Fixing excessive whitespace in: $file${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's/[[:space:]]\{3,\}$/  /' "$file"
        else
            sed -i 's/[[:space:]]\{3,\}$/  /' "$file"
        fi
        ((fixed_count++))
    fi
done

# Summary
echo
echo -e "${GREEN}✅ Whitespace check complete!${NC}"
echo -e "   Checked: $checked_count files"
echo -e "   Fixed: $fixed_count files"

if [ $fixed_count -gt 0 ]; then
    echo
    echo -e "${YELLOW}⚠️  Files were modified. Please review and commit the changes.${NC}"
    exit 1
else
    echo -e "${GREEN}✨ All files are clean!${NC}"
    exit 0
fi