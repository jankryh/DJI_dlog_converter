#!/usr/bin/env bash
set -euo pipefail

# Test script to isolate the validation issue

echo "Starting test..."

# Source modules
source lib/core/logging.sh
echo "Logging loaded"

source lib/core/utils.sh  
echo "Utils loaded"

source lib/core/config.sh
echo "Config loaded"

# Initialize
init_default_config
echo "Config initialized"

# Test validation
echo "Testing validate_config..."
validate_config
echo "validate_config completed with exit code: $?"

echo "Testing check_dependencies..."
check_dependencies  
echo "check_dependencies completed"

echo "All tests passed!"