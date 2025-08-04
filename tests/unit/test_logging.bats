#!/usr/bin/env bats

# Unit tests for lib/core/logging.sh
# Tests logging functions, colors, and log levels

load '../test_helper/test_helper.bash'

setup() {
    # Load common test setup
    source "tests/test_helper/test_helper.bash"
    
    # Source the logging module
    source_module "lib/core/logging.sh"
    
    # Set up test log file
    export TEST_LOG_FILE="$TEMP_TEST_DIR/test.log"
    export ENABLE_FILE_LOGGING="true"
    export LOG_FILE="$TEST_LOG_FILE"
}

@test "log_info: should output info message with color" {
    run log_info "Test info message"
    assert_success
    assert_output --partial "Test info message"
    # Should contain color codes (ANSI escape sequences)
    assert_output --regexp $'\\033\\[[0-9;]*m'
}

@test "log_warning: should output warning message" {
    run log_warning "Test warning message"
    assert_success
    assert_output --partial "Test warning message"
    assert_output --partial "⚠️"
}

@test "log_error: should output error message" {
    run log_error "Test error message"
    assert_success
    assert_output --partial "Test error message"
    assert_output --partial "❌"
}

@test "log_debug: should output debug message when debug enabled" {
    export DEBUG_LOGGING="true"
    
    run log_debug "Test debug message"
    assert_success
    assert_output --partial "Test debug message"
    assert_output --partial "🐛"
}

@test "log_debug: should not output when debug disabled" {
    export DEBUG_LOGGING="false"
    
    run log_debug "Test debug message"
    assert_success
    assert_output ""
}

@test "log_success: should output success message" {
    run log_success "Test success message"
    assert_success
    assert_output --partial "Test success message"
    assert_output --partial "✅"
}

@test "file logging: should write to log file when enabled" {
    export ENABLE_FILE_LOGGING="true"
    
    log_info "Test file logging message"
    
    assert_file_exist "$TEST_LOG_FILE"
    assert_file_contains "$TEST_LOG_FILE" "Test file logging message"
}

@test "file logging: should not create file when disabled" {
    export ENABLE_FILE_LOGGING="false"
    
    log_info "Test message"
    
    assert_file_not_exist "$TEST_LOG_FILE"
}

@test "color output: should disable colors when NO_COLOR is set" {
    export NO_COLOR="1"
    
    run log_info "Test colorless message"
    assert_success
    assert_output --partial "Test colorless message"
    # Should not contain ANSI color codes
    refute_output --regexp $'\\033\\[[0-9;]*m'
}

@test "color output: should disable colors when not a terminal" {
    # Mock isatty to return false (not a terminal)
    isatty() { return 1; }
    export -f isatty
    
    run log_info "Test non-tty message"
    assert_success
    assert_output --partial "Test non-tty message"
    # Should not contain ANSI color codes
    refute_output --regexp $'\\033\\[[0-9;]*m'
}

@test "_log function: should handle different log levels" {
    run _log "INFO" "Blue message" "34"
    assert_success
    assert_output --partial "Blue message"
    
    run _log "ERROR" "Red message" "31"
    assert_success
    assert_output --partial "Red message"
}

@test "_log function: should include timestamp in file output" {
    export ENABLE_FILE_LOGGING="true"
    
    _log "INFO" "Timestamped message" "32"
    
    assert_file_exist "$TEST_LOG_FILE"
    assert_file_contains "$TEST_LOG_FILE" "Timestamped message"
    # Should contain timestamp format (e.g., 2025-01-08 10:30:45)
    grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" "$TEST_LOG_FILE"
}

@test "log functions: should handle empty messages" {
    run log_info ""
    assert_success
    
    run log_warning ""
    assert_success
    
    run log_error ""
    assert_success
}

@test "log functions: should handle special characters" {
    run log_info "Message with 'quotes' and \"double quotes\""
    assert_success
    assert_output --partial "quotes"
    
    run log_info "Message with $special *characters* and [brackets]"
    assert_success
    assert_output --partial "special"
    assert_output --partial "characters"
}

@test "log functions: should handle multiline messages" {
    local multiline_msg="Line 1
Line 2
Line 3"
    
    run log_info "$multiline_msg"
    assert_success
    assert_output --partial "Line 1"
    assert_output --partial "Line 2"
    assert_output --partial "Line 3"
}

@test "verbose logging: should output verbose messages when enabled" {
    export VERBOSE_LOGGING="true"
    
    run log_verbose "Test verbose message"
    assert_success
    assert_output --partial "Test verbose message"
}

@test "verbose logging: should not output when disabled" {
    export VERBOSE_LOGGING="false"
    
    run log_verbose "Test verbose message"
    assert_success
    assert_output ""
}

@test "progress functions: should display progress bar" {
    run show_progress "50" "100" "Processing"
    assert_success
    assert_output --partial "Processing"
    assert_output --partial "50/100"
    assert_output --partial "%"
}

@test "progress functions: should handle zero values" {
    run show_progress "0" "100" "Starting"
    assert_success
    assert_output --partial "Starting"
    assert_output --partial "0/100"
}

@test "progress functions: should handle completion" {
    run show_progress "100" "100" "Complete"
    assert_success
    assert_output --partial "Complete"
    assert_output --partial "100/100"
    assert_output --partial "100%"
}

@test "log file rotation: should handle large log files" {
    export ENABLE_FILE_LOGGING="true"
    export MAX_LOG_SIZE="1024"  # 1KB for testing
    
    # Write many log entries to exceed size limit
    for i in {1..100}; do
        log_info "Log entry number $i with some additional text to make it longer"
    done
    
    assert_file_exist "$TEST_LOG_FILE"
    
    # Check if file exists and has content
    [[ -s "$TEST_LOG_FILE" ]]
}

@test "error handling: should continue on file write errors" {
    # Try to write to read-only directory
    mkdir -p "$TEMP_TEST_DIR/readonly"
    chmod 444 "$TEMP_TEST_DIR/readonly"
    export LOG_FILE="$TEMP_TEST_DIR/readonly/test.log"
    export ENABLE_FILE_LOGGING="true"
    
    run log_info "Test message with file error"
    assert_success
    assert_output --partial "Test message with file error"
    
    # Clean up
    chmod 755 "$TEMP_TEST_DIR/readonly"
}