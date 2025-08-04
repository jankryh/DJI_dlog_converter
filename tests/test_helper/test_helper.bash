#!/usr/bin/env bash

# Test helper functions for DJI Video Processor testing
# This file is sourced by all test files

# Load BATS helper libraries  
# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
load "$SCRIPT_DIR/bats-support/load"
load "$SCRIPT_DIR/bats-assert/load"
load "$SCRIPT_DIR/bats-file/load"

# Test directory paths
TEST_DIR="$BATS_TEST_DIRNAME"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
LIB_DIR="$PROJECT_ROOT/lib"
BIN_DIR="$PROJECT_ROOT/bin"

# Test data directories (use absolute paths)
TEST_DATA_DIR="$(cd "$TEST_DIR" && pwd)/data"
TEMP_TEST_DIR="$(cd "$TEST_DIR" && pwd)/tmp"
TEST_CONFIG="$TEMP_TEST_DIR/test-config.yml"

# Setup function - runs before each test
setup() {
    # Ensure we have absolute paths for temp directory
    local test_dir_abs
    test_dir_abs="$(cd "$BATS_TEST_DIRNAME" && pwd)"
    TEMP_TEST_DIR="$test_dir_abs/tmp"
    
    # Create temporary test directory with absolute path
    mkdir -p "$TEMP_TEST_DIR"
    
    # TEST_CONFIG is already set globally
    
    # Change to project root for consistent paths
    cd "$PROJECT_ROOT"
    
    # Export required environment variables
    export LIB_DIR="$LIB_DIR"
    export SCRIPT_DIR="$PROJECT_ROOT"
    
    # Prevent actual file operations during tests
    export DJI_TEST_MODE="true"
}

# Teardown function - runs after each test  
teardown() {
    # Clean up temporary files
    if [[ -d "$TEMP_TEST_DIR" ]]; then
        rm -rf "$TEMP_TEST_DIR"
    fi
    
    # Return to original directory
    cd "$BATS_TEST_DIRNAME"
}

# Helper function: Create test configuration
create_test_config() {
    local config_file="${1:-}"
    
    # If no file specified, create in temp directory
    if [[ -z "$config_file" ]]; then
        local test_dir_abs
        test_dir_abs="$(cd "$BATS_TEST_DIRNAME" && pwd)"
        config_file="$test_dir_abs/tmp/test-config.yml"
    fi
    
    # Ensure directory exists for config file
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" << 'EOF'
# Test configuration for DJI Video Processor
source_directory: "./input"
final_directory: "./output" 
lut_file: "./luts/Avata2.cube"
quality_preset: "standard"
parallel_jobs: "auto"
auto_backup: false
skip_existing: true
verbose_logging: false

file_extensions:
  - "mp4"
  - "MP4"
  - "mov"
  - "MOV"
EOF
}

# Helper function: Create test video file
create_test_video() {
    local filename="${1:-test_video.mp4}"
    local directory="${2:-$TEMP_TEST_DIR}"
    
    mkdir -p "$directory"
    # Create dummy video file for testing
    touch "$directory/$filename"
    echo "dummy video content" > "$directory/$filename"
}

# Helper function: Create test LUT file
create_test_lut() {
    local filename="${1:-Avata2.cube}"
    local directory="${2:-$TEMP_TEST_DIR}"
    
    mkdir -p "$directory"
    cat > "$directory/$filename" << 'EOF'
# Test LUT file
TITLE "Test LUT"
LUT_3D_SIZE 32

0.0 0.0 0.0
0.1 0.1 0.1
0.2 0.2 0.2
EOF
}

# Helper function: Mock external dependencies
mock_dependencies() {
    # Create mock ffmpeg
    mkdir -p "$TEMP_TEST_DIR/bin"
    cat > "$TEMP_TEST_DIR/bin/ffmpeg" << 'EOF'
#!/bin/bash
echo "Mock FFmpeg v4.4.0"
exit 0
EOF
    chmod +x "$TEMP_TEST_DIR/bin/ffmpeg"
    
    # Add to PATH
    export PATH="$TEMP_TEST_DIR/bin:$PATH"
}

# Helper function: Assert command succeeds
assert_command_success() {
    local command="$1"
    run $command
    assert_success
}

# Helper function: Assert command fails  
assert_command_failure() {
    local command="$1"
    run $command
    assert_failure
}

# Helper function: Source module safely
source_module() {
    local module_path="$1"
    
    if [[ -f "$module_path" ]]; then
        source "$module_path"
    else
        echo "ERROR: Module not found: $module_path" >&2
        return 1
    fi
}

# Helper function: Test file permissions
assert_executable() {
    local file="$1"
    assert_file_exist "$file"
    assert [ -x "$file" ]
}

# Helper function: Generate random test data
generate_test_string() {
    local length="${1:-10}"
    head /dev/urandom | base64 | head -c "$length"
}