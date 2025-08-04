#!/usr/bin/env bats

# Integration tests for bin/dji-processor CLI
# Tests complete command line interface and workflows

load '../test_helper/test_helper.bash'

setup() {
    # Load common test setup
    source "tests/test_helper/test_helper.bash"
    
    # Set up test environment
    export PATH="$BIN_DIR:$PATH"
    export LIB_DIR="$PROJECT_ROOT/lib"
    
    # Create test directories and files
    mkdir -p "./input" "./output" "./luts" "./backup"
    create_test_video "test1.mp4" "./input"
    create_test_video "test2.MP4" "./input"
    create_test_lut "Avata2.cube" "./luts"
    
    # Mock external dependencies
    mock_dependencies
}

@test "dji-processor: should show help when no arguments" {
    run ./bin/dji-processor
    assert_success
    assert_output --partial "DJI Video Processor"
    assert_output --partial "Commands:"
}

@test "dji-processor help: should display help message" {
    run ./bin/dji-processor help
    assert_success
    assert_output --partial "DJI Video Processor"
    assert_output --partial "process"
    assert_output --partial "validate"
    assert_output --partial "config"
    assert_output --partial "status"
}

@test "dji-processor --help: should display help message" {
    run ./bin/dji-processor --help
    assert_success
    assert_output --partial "DJI Video Processor"
}

@test "dji-processor version: should show version" {
    run ./bin/dji-processor version
    assert_success
    assert_output --regexp "DJI Video Processor v[0-9]+\.[0-9]+\.[0-9]+"
}

@test "dji-processor --version: should show version" {
    run ./bin/dji-processor --version
    assert_success
    assert_output --regexp "v[0-9]+\.[0-9]+\.[0-9]+"
}

@test "dji-processor status: should show system status" {
    run ./bin/dji-processor status
    assert_success
    assert_output --partial "DJI Processor Status"
    assert_output --partial "Dependencies"
    assert_output --partial "Platform"
}

@test "dji-processor validate: should validate setup" {
    run ./bin/dji-processor validate
    assert_success
    assert_output --partial "Validating DJI Processor Setup"
    assert_output --partial "Dependencies check"
    assert_output --partial "Configuration check"
}

@test "dji-processor config show: should display configuration" {
    run ./bin/dji-processor config show
    assert_success
    assert_output --partial "Current Configuration"
    assert_output --partial "Source Directory"
    assert_output --partial "Output Directory"
    assert_output --partial "LUT File"
}

@test "dji-processor config validate: should validate configuration" {
    run ./bin/dji-processor config validate
    assert_success
}

@test "dji-processor config create: should create default config" {
    # Remove existing config
    rm -f dji-config.yml
    
    run ./bin/dji-processor config create
    assert_success
    assert_file_exist "dji-config.yml"
}

@test "dji-processor process --dry-run: should show processing plan" {
    run ./bin/dji-processor process --dry-run
    assert_success
    assert_output --partial "DRY RUN"
    assert_output --partial "Found"
    assert_output --partial "files to process"
    assert_output --partial "test1.mp4"
    assert_output --partial "test2.MP4"
}

@test "dji-processor process --dry-run --verbose: should show detailed info" {
    run ./bin/dji-processor process --dry-run --verbose
    assert_success
    assert_output --partial "DRY RUN"
    assert_output --partial "Verbose mode enabled"
    assert_output --partial "Hardware acceleration"
}

@test "dji-processor process with custom options: should accept parameters" {
    run ./bin/dji-processor process --dry-run --quality high --parallel 2
    assert_success
    assert_output --partial "DRY RUN"
    assert_output --partial "Quality: high"
}

@test "dji-processor process --sequential: should process in sequential mode" {
    run timeout 5s ./bin/dji-processor process --sequential || true
    # Should start processing (we interrupt with timeout)
    assert_output --partial "Sequential processing"
}

@test "dji-processor: should handle invalid commands" {
    run ./bin/dji-processor invalid_command
    assert_failure
    assert_output --partial "Unknown command"
}

@test "dji-processor: should handle invalid options" {
    run ./bin/dji-processor process --invalid-option
    assert_failure
    assert_output --partial "Unknown option"
}

@test "dji-processor process: should handle missing source directory" {
    # Remove input directory
    rm -rf "./input"
    
    run ./bin/dji-processor process --dry-run
    assert_success
    assert_output --partial "No video files found"
}

@test "dji-processor process: should handle missing LUT file" {
    # Remove LUT file
    rm -f "./luts/Avata2.cube"
    
    run ./bin/dji-processor validate
    assert_failure
    assert_output --partial "LUT file not found"
}

@test "dji-processor: should create output directory if missing" {
    # Remove output directory
    rm -rf "./output"
    
    run ./bin/dji-processor process --dry-run
    assert_success
    assert_dir_exist "./output"
}

@test "dji-processor: should handle configuration file errors" {
    # Create invalid config file
    echo "invalid: yaml: content:" > dji-config.yml
    
    run ./bin/dji-processor validate
    # Should handle gracefully or show meaningful error
    if [[ $status -ne 0 ]]; then
        assert_output --partial "configuration"
    fi
}

@test "dji-processor: should handle environment variable overrides" {
    export DJI_QUALITY="professional"
    export DJI_PARALLEL="1"
    
    run ./bin/dji-processor config show
    assert_success
    assert_output --partial "Quality Preset: professional"
    assert_output --partial "Parallel Jobs: 1"
    
    unset DJI_QUALITY DJI_PARALLEL
}

@test "dji-processor: should handle custom source directory" {
    mkdir -p "./custom_input"
    create_test_video "custom.mp4" "./custom_input"
    
    run ./bin/dji-processor process --dry-run --source "./custom_input"
    assert_success
    assert_output --partial "custom.mp4"
}

@test "dji-processor: should handle custom output directory" {
    run ./bin/dji-processor process --dry-run --output "./custom_output"
    assert_success
    assert_dir_exist "./custom_output"
}

@test "dji-processor: should handle custom LUT file" {
    create_test_lut "custom.cube" "./luts"
    
    run ./bin/dji-processor process --dry-run --lut "./luts/custom.cube"
    assert_success
    assert_output --partial "LUT file: ./luts/custom.cube"
}

@test "dji-processor: should validate quality parameter" {
    run ./bin/dji-processor process --dry-run --quality invalid
    assert_failure
    assert_output --partial "Invalid quality"
}

@test "dji-processor: should validate parallel parameter" {
    run ./bin/dji-processor process --dry-run --parallel 0
    assert_failure
    assert_output --partial "Invalid parallel"
    
    run ./bin/dji-processor process --dry-run --parallel -1
    assert_failure
    assert_output --partial "Invalid parallel"
}

@test "dji-processor: should handle file permissions" {
    # Create read-only input directory
    chmod 444 "./input"
    
    run ./bin/dji-processor validate
    # Should handle gracefully
    if [[ $status -ne 0 ]]; then
        assert_output --partial "permission"
    fi
    
    # Restore permissions
    chmod 755 "./input"
}

@test "dji-processor: should show proper exit codes" {
    # Success case
    run ./bin/dji-processor help
    assert_success
    [[ $status -eq 0 ]]
    
    # Failure case
    run ./bin/dji-processor invalid_command
    assert_failure
    [[ $status -ne 0 ]]
}