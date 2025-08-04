#!/usr/bin/env bats

# Unit tests for lib/core/config.sh
# Tests YAML configuration loading, parsing, and validation

load '../test_helper/test_helper.bash'

setup() {
    # Load common test setup
    source "tests/test_helper/test_helper.bash"
    
    # Source the required modules
    source_module "lib/core/logging.sh"
    source_module "lib/core/utils.sh"
    source_module "lib/core/config.sh"
    
    # Create test config file
    create_test_config
}

@test "parse_config_value: should extract simple values" {
    # Create test config with simple key-value pairs
    cat > "$TEST_CONFIG" << 'EOF'
quality_preset: "standard"
parallel_jobs: "auto"
auto_backup: false
EOF

    run parse_config_value "$TEST_CONFIG" "quality_preset"
    assert_success
    assert_output "standard"
    
    run parse_config_value "$TEST_CONFIG" "parallel_jobs"
    assert_success
    assert_output "auto"
}

@test "parse_config_value: should handle missing keys" {
    run parse_config_value "$TEST_CONFIG" "nonexistent_key"
    assert_success
    assert_output ""
}

@test "parse_config_value: should handle quoted and unquoted values" {
    cat > "$TEST_CONFIG" << 'EOF'
quoted_value: "hello world"
unquoted_value: hello
number_value: 42
boolean_value: true
EOF

    run parse_config_value "$TEST_CONFIG" "quoted_value"
    assert_success
    assert_output "hello world"
    
    run parse_config_value "$TEST_CONFIG" "unquoted_value"
    assert_success
    assert_output "hello"
    
    run parse_config_value "$TEST_CONFIG" "number_value"
    assert_success
    assert_output "42"
}

@test "parse_config_bool: should parse boolean values correctly" {
    cat > "$TEST_CONFIG" << 'EOF'
bool_true: true
bool_false: false
bool_yes: yes
bool_no: no
bool_quoted_true: "true"
EOF

    run parse_config_bool "$TEST_CONFIG" "bool_true"
    assert_success
    assert_output "true"
    
    run parse_config_bool "$TEST_CONFIG" "bool_false"
    assert_success
    assert_output "false"
    
    run parse_config_bool "$TEST_CONFIG" "bool_yes"
    assert_success
    assert_output "true"
    
    run parse_config_bool "$TEST_CONFIG" "bool_no"
    assert_success
    assert_output "false"
}

@test "parse_config_bool: should handle missing boolean keys" {
    run parse_config_bool "$TEST_CONFIG" "nonexistent_bool"
    assert_success
    assert_output "false"
}

@test "load_config_file: should load valid config file" {
    run load_config_file "$TEST_CONFIG"
    assert_success
    
    # Check that environment variables are set
    [[ -n "$SOURCE_DIR" ]]
    [[ -n "$FINAL_DIR" ]]
    [[ -n "$LUT_FILE" ]]
    [[ -n "$QUALITY_PRESET" ]]
}

@test "load_config_file: should handle missing config file" {
    run load_config_file "$TEMP_TEST_DIR/nonexistent.yml"
    assert_failure
}

@test "load_config_file: should set default values" {
    # Create minimal config
    cat > "$TEST_CONFIG" << 'EOF'
source_directory: "./test_input"
EOF

    run load_config_file "$TEST_CONFIG"
    assert_success
    
    # Check default values are set
    [[ "$QUALITY_PRESET" == "standard" ]]
    [[ "$PARALLEL_JOBS" == "auto" ]]
    [[ "$AUTO_BACKUP" == "false" ]]
}

@test "get_config_value: should return config values after loading" {
    load_config_file "$TEST_CONFIG"
    
    run get_config_value "SOURCE_DIR"
    assert_success
    assert_output "./input"
    
    run get_config_value "QUALITY_PRESET"
    assert_success
    assert_output "standard"
}

@test "get_config_value: should handle undefined variables" {
    run get_config_value "UNDEFINED_VAR"
    assert_success
    assert_output ""
}

@test "create_default_config: should create config file" {
    local default_config="$TEMP_TEST_DIR/default.yml"
    
    run create_default_config "$default_config"
    assert_success
    assert_file_exist "$default_config"
    
    # Check content contains expected keys
    assert_file_contains "$default_config" "source_directory:"
    assert_file_contains "$default_config" "final_directory:"
    assert_file_contains "$default_config" "lut_file:"
}

@test "create_default_config: should not overwrite existing config" {
    # Create existing config
    echo "existing: true" > "$TEST_CONFIG"
    
    run create_default_config "$TEST_CONFIG"
    assert_success
    
    # Should preserve existing content
    assert_file_contains "$TEST_CONFIG" "existing: true"
}

@test "validate_config: should accept valid configuration" {
    # Create directories and files referenced in config
    mkdir -p "./input"
    mkdir -p "./luts"
    create_test_lut "Avata2.cube" "./luts"
    
    load_config_file "$TEST_CONFIG"
    
    run validate_config
    assert_success
}

@test "validate_config: should warn about missing source directory" {
    # Don't create input directory
    load_config_file "$TEST_CONFIG"
    
    run validate_config
    # Should succeed but with warnings
    assert_success
}

@test "validate_config: should fail on missing LUT file" {
    # Create input directory but not LUT file
    mkdir -p "./input"
    load_config_file "$TEST_CONFIG"
    
    run validate_config
    assert_failure
}

@test "validate_config: should fail on invalid quality preset" {
    # Create valid setup
    mkdir -p "./input"
    mkdir -p "./luts" 
    create_test_lut "Avata2.cube" "./luts"
    
    # Set invalid quality preset
    cat > "$TEST_CONFIG" << 'EOF'
source_directory: "./input"
final_directory: "./output"
lut_file: "./luts/Avata2.cube"
quality_preset: "invalid_quality"
parallel_jobs: "auto"
EOF

    load_config_file "$TEST_CONFIG"
    
    run validate_config
    assert_failure
}

@test "validate_config: should fail on invalid parallel jobs" {
    # Create valid setup
    mkdir -p "./input"
    mkdir -p "./luts"
    create_test_lut "Avata2.cube" "./luts"
    
    # Set invalid parallel jobs
    cat > "$TEST_CONFIG" << 'EOF'
source_directory: "./input"
final_directory: "./output" 
lut_file: "./luts/Avata2.cube"
quality_preset: "standard"
parallel_jobs: "invalid"
EOF

    load_config_file "$TEST_CONFIG"
    
    run validate_config
    assert_failure
}

@test "apply_config: should handle environment variable overrides" {
    # Set environment variables
    export DJI_QUALITY="high"
    export DJI_PARALLEL="4"
    
    load_config_file "$TEST_CONFIG"
    apply_config
    
    # Check that environment variables override config
    [[ "$QUALITY_PRESET" == "high" ]]
    [[ "$PARALLEL_JOBS" == "4" ]]
    
    # Clean up
    unset DJI_QUALITY DJI_PARALLEL
}

@test "apply_config: should preserve config values when no env vars" {
    load_config_file "$TEST_CONFIG"
    apply_config
    
    # Check that config values are preserved
    [[ "$QUALITY_PRESET" == "standard" ]]
    [[ "$PARALLEL_JOBS" == "auto" ]]
}

@test "config loading: should handle complex YAML structure" {
    cat > "$TEST_CONFIG" << 'EOF'
# Complex config with comments and arrays
source_directory: "./input"
final_directory: "./output"
lut_file: "./luts/Avata2.cube"

# Processing settings
quality_preset: "high"
parallel_jobs: 8

# Backup and behavior
auto_backup: true
skip_existing: false

# File extensions
file_extensions:
  - "mp4"
  - "MP4"
  - "mov"
  - "MOV"
  - "avi"
EOF

    run load_config_file "$TEST_CONFIG"
    assert_success
    
    # Check parsed values
    [[ "$QUALITY_PRESET" == "high" ]]
    [[ "$PARALLEL_JOBS" == "8" ]]
    [[ "$AUTO_BACKUP" == "true" ]]
}