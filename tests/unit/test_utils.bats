#!/usr/bin/env bats

# Unit tests for lib/core/utils.sh
# Tests utility functions, validation, and platform detection

load '../test_helper/test_helper.bash'

setup() {
    # Load common test setup
    source "tests/test_helper/test_helper.bash"
    
    # Source the utils module
    source_module "lib/core/logging.sh"
    source_module "lib/core/utils.sh"
}

@test "detect_platform: should detect macOS" {
    # Mock uname to return Darwin
    uname() { echo "Darwin"; }
    export -f uname
    
    run detect_platform
    assert_success
    assert_output "macos"
}

@test "detect_platform: should detect Linux" {
    # Mock uname to return Linux
    uname() { echo "Linux"; }
    export -f uname
    
    run detect_platform
    assert_success
    assert_output "linux"
}

@test "detect_platform: should handle unknown platform" {
    # Mock uname to return unknown OS
    uname() { echo "FreeBSD"; }
    export -f uname
    
    run detect_platform
    assert_success
    assert_output "unknown"
}

@test "get_cpu_cores: should return positive number" {
    run get_cpu_cores
    assert_success
    
    # Should return a positive integer
    [[ "$output" =~ ^[1-9][0-9]*$ ]]
}

@test "validate_directory: should accept existing directory" {
    # Create test directory
    mkdir -p "$TEMP_TEST_DIR/test_dir"
    
    run validate_directory "$TEMP_TEST_DIR/test_dir"
    assert_success
}

@test "validate_directory: should reject non-existent directory" {
    run validate_directory "$TEMP_TEST_DIR/nonexistent"
    assert_failure
}

@test "validate_directory: should reject file as directory" {
    # Ensure temp directory exists
    mkdir -p "$TEMP_TEST_DIR"
    
    # Create test file
    touch "$TEMP_TEST_DIR/test_file"
    
    run validate_directory "$TEMP_TEST_DIR/test_file"
    assert_failure
}

@test "validate_file: should accept existing file" {
    # Ensure temp directory exists
    mkdir -p "$TEMP_TEST_DIR"
    
    # Create test file
    touch "$TEMP_TEST_DIR/test_file.txt"
    
    run validate_file "$TEMP_TEST_DIR/test_file.txt"
    assert_success
}

@test "validate_file: should reject non-existent file" {
    run validate_file "$TEMP_TEST_DIR/nonexistent.txt"
    assert_failure
}

@test "validate_file: should reject directory as file" {
    # Create test directory
    mkdir -p "$TEMP_TEST_DIR/test_dir"
    
    run validate_file "$TEMP_TEST_DIR/test_dir"
    assert_failure
}

@test "validate_quality: should accept valid quality presets" {
    run validate_quality "draft"
    assert_success
    
    run validate_quality "standard"  
    assert_success
    
    run validate_quality "high"
    assert_success
    
    run validate_quality "professional"
    assert_success
}

@test "validate_quality: should reject invalid quality preset" {
    run validate_quality "invalid"
    assert_failure
    
    run validate_quality ""
    assert_failure
}

@test "validate_parallel: should accept valid parallel values" {
    run validate_parallel "1"
    assert_success
    
    run validate_parallel "4"
    assert_success
    
    run validate_parallel "auto"
    assert_success
}

@test "validate_parallel: should reject invalid parallel values" {
    run validate_parallel "0"
    assert_failure
    
    run validate_parallel "-1"
    assert_failure
    
    run validate_parallel "abc"
    assert_failure
    
    run validate_parallel ""
    assert_failure
}

@test "validate_yes_no: should accept valid boolean values" {
    run validate_yes_no "true"
    assert_success
    
    run validate_yes_no "false"
    assert_success
    
    run validate_yes_no "yes"
    assert_success
    
    run validate_yes_no "no"
    assert_success
}

@test "validate_yes_no: should reject invalid boolean values" {
    run validate_yes_no "maybe"
    assert_failure
    
    run validate_yes_no "1"
    assert_failure
    
    run validate_yes_no ""
    assert_failure
}

@test "format_file_size: should format bytes correctly" {
    run format_file_size "1024"
    assert_success
    assert_output "1.0K"
    
    run format_file_size "1048576"
    assert_success
    assert_output "1.0M"
    
    run format_file_size "1073741824"
    assert_success
    assert_output "1.0G"
}

@test "format_file_size: should handle zero and small values" {
    run format_file_size "0"
    assert_success
    assert_output "0B"
    
    run format_file_size "512" 
    assert_success
    assert_output "512B"
}

@test "format_duration: should format seconds correctly" {
    run format_duration "0"
    assert_success
    assert_output "0s"
    
    run format_duration "65"
    assert_success
    assert_output "1m 5s"
    
    run format_duration "3665"
    assert_success
    assert_output "1h 1m 5s"
}

@test "get_quality_settings: should return correct settings for each preset" {
    run get_quality_settings "draft"
    assert_success
    assert_line --index 0 "28"  # CRF
    assert_line --index 1 "ultrafast"  # Preset
    
    run get_quality_settings "standard"
    assert_success
    assert_line --index 0 "23"
    assert_line --index 1 "medium"
    
    run get_quality_settings "high"
    assert_success
    assert_line --index 0 "20"
    assert_line --index 1 "slow"
    
    run get_quality_settings "professional"
    assert_success
    assert_line --index 0 "18"
    assert_line --index 1 "veryslow"
}

@test "get_quality_settings: should handle invalid quality preset" {
    run get_quality_settings "invalid"
    assert_failure
}

@test "check_dependencies: should detect ffmpeg when available" {
    # Mock ffmpeg
    mock_dependencies
    
    run check_dependencies
    assert_success
}

@test "check_dependencies: should fail when ffmpeg missing" {
    # Ensure ffmpeg is not in PATH
    export PATH="/usr/bin:/bin"
    
    run check_dependencies
    assert_failure
}

@test "get_available_space: should return positive number" {
    run get_available_space "."
    assert_success
    
    # Should return a positive number (in GB)
    [[ "$output" =~ ^[0-9]+$ ]]
}