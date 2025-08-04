# Testing Guide - DJI Video Processor

This document covers the comprehensive testing framework implemented with BATS (Bash Automated Testing System).

## Overview

The DJI Video Processor uses a modern testing approach with:
- **BATS Core 1.12.0** - TAP-compliant testing framework
- **Helper modules** - assertions, file operations, and support functions
- **Unit tests** - individual module testing
- **Integration tests** - full CLI workflow testing
- **Automated test runner** - convenient execution and reporting

## Quick Start

```bash
# Run all tests
make test

# Run specific test types
make test-unit
make test-integration

# Run with verbose output
make test-verbose

# Setup development environment
make setup
```

## Test Structure

```
tests/
├── test_helper/
│   ├── test_helper.bash      # Common test utilities
│   ├── bats-support/         # BATS support library
│   ├── bats-assert/          # Assertion functions
│   └── bats-file/            # File system assertions
├── unit/
│   ├── test_utils.bats       # Core utilities tests
│   ├── test_config.bats      # Configuration tests
│   └── test_logging.bats     # Logging system tests
├── integration/
│   └── test_cli.bats         # CLI integration tests
├── run-tests.sh              # Test runner script
└── reports/                  # Test reports and artifacts
```

## Writing Tests

### Unit Test Example

```bash
#!/usr/bin/env bats

load '../test_helper/test_helper'

setup() {
    source "tests/test_helper/test_helper.bash"
    source_module "lib/core/utils.sh"
}

@test "validate_directory: should accept existing directory" {
    mkdir -p "$TEMP_TEST_DIR/test_dir"
    
    run validate_directory "$TEMP_TEST_DIR/test_dir"
    assert_success
}

@test "format_file_size: should format bytes correctly" {
    run format_file_size "1024"
    assert_success
    assert_output "1.0K"
}
```

### Integration Test Example

```bash
#!/usr/bin/env bats

load '../test_helper/test_helper'

setup() {
    source "tests/test_helper/test_helper.bash"
    mkdir -p "./input" "./luts"
    create_test_video "test.mp4" "./input"
    create_test_lut "Avata2.cube" "./luts"
    mock_dependencies
}

@test "dji-processor help: should display help message" {
    run ./bin/dji-processor help
    assert_success
    assert_output --partial "DJI Video Processor"
    assert_output --partial "Commands:"
}
```

## Test Helper Functions

### Core Helpers

```bash
# Load modules safely
source_module "lib/core/utils.sh"

# Create test data
create_test_config
create_test_video "test.mp4" "./temp"
create_test_lut "test.cube" "./temp"

# Mock external dependencies
mock_dependencies

# Assert command results
assert_command_success "./bin/dji-processor help"
assert_command_failure "./bin/dji-processor invalid"
```

### Assertion Functions

```bash
# Basic assertions (from bats-assert)
assert_success
assert_failure
assert_output "expected text"
assert_output --partial "partial text"
assert_line --index 0 "first line"

# File assertions (from bats-file)
assert_file_exist "path/to/file"
assert_file_not_exist "path/to/file"
assert_dir_exist "path/to/directory"
assert_file_contains "file" "content"
assert_executable "script"
```

## Test Categories

### 1. Unit Tests

Test individual functions and modules in isolation:

#### `test_utils.bats`
- Platform detection (`detect_platform`)
- File validation (`validate_file`, `validate_directory`)
- Input validation (`validate_quality`, `validate_parallel`)
- Formatting functions (`format_file_size`, `format_duration`)
- System utilities (`get_cpu_cores`, `get_available_space`)

#### `test_config.bats`
- YAML parsing (`parse_config_value`, `parse_config_bool`)
- Configuration loading (`load_config_file`)
- Validation (`validate_config`)
- Environment overrides (`apply_config`)

#### `test_logging.bats`
- Log levels (`log_info`, `log_warning`, `log_error`)
- Color output handling
- File logging functionality
- Debug/verbose mode behavior

### 2. Integration Tests

Test complete workflows and CLI interactions:

#### `test_cli.bats`
- Command-line argument parsing
- Help and version commands
- Configuration management
- Process workflows (dry-run, validation)
- Error handling and edge cases

## Running Tests

### Basic Commands

```bash
# All tests
./tests/run-tests.sh

# Specific test types
./tests/run-tests.sh unit
./tests/run-tests.sh integration

# With options
./tests/run-tests.sh --verbose unit
./tests/run-tests.sh --filter "config" 
./tests/run-tests.sh --tap all
```

### Using Makefile

```bash
# Quick test commands
make test              # All tests
make test-unit         # Unit tests only
make test-integration  # Integration tests only
make test-verbose      # Verbose output

# Filtered tests
make test-utils        # Utils tests only
make test-config       # Config tests only
make test-cli          # CLI tests only

# Development workflow
make dev               # Lint + unit tests
make ci                # Full CI pipeline
```

### Test Outputs

#### Standard Output
```
✓ validate_directory: should accept existing directory
✓ validate_directory: should reject non-existent directory
✓ format_file_size: should format bytes correctly

3 tests, 0 failures
```

#### TAP Output
```bash
make test-tap
```
```
1..3
ok 1 validate_directory: should accept existing directory
ok 2 validate_directory: should reject non-existent directory  
ok 3 format_file_size: should format bytes correctly
```

#### JUnit XML Report
```bash
make test-junit
```
Creates `tests/reports/junit-report.xml` for CI integration.

## Test Environment

### Setup and Teardown

Each test gets a clean environment:

```bash
setup() {
    # Common setup for all tests
    mkdir -p "$TEMP_TEST_DIR"
    cd "$PROJECT_ROOT"
    export DJI_TEST_MODE="true"
}

teardown() {
    # Cleanup after each test
    rm -rf "$TEMP_TEST_DIR"
    cd "$BATS_TEST_DIRNAME"
}
```

### Mock Functions

```bash
# Mock external commands
mock_dependencies() {
    mkdir -p "$TEMP_TEST_DIR/bin"
    cat > "$TEMP_TEST_DIR/bin/ffmpeg" << 'EOF'
#!/bin/bash
echo "Mock FFmpeg v4.4.0"
exit 0
EOF
    chmod +x "$TEMP_TEST_DIR/bin/ffmpeg"
    export PATH="$TEMP_TEST_DIR/bin:$PATH"
}

# Mock system commands
uname() { echo "Darwin"; }
export -f uname
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive
      
      - name: Install BATS
        run: |
          sudo apt-get update
          sudo apt-get install bats
      
      - name: Run tests
        run: make ci
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: tests/reports/
```

### Pre-commit Hooks

```bash
# Setup git hooks
make git-setup

# Manual pre-commit check
make dev
```

## Best Practices

### 1. Test Organization

- **One test file per module** - keep tests focused
- **Descriptive test names** - explain what is being tested
- **Arrange-Act-Assert pattern** - setup, execute, verify

### 2. Test Data

- **Use temporary directories** - avoid conflicts
- **Clean up after tests** - prevent side effects
- **Mock external dependencies** - reliable, fast tests

### 3. Assertions

- **Specific assertions** - test exact expectations
- **Error messages** - include helpful context
- **Edge cases** - test boundaries and error conditions

### 4. Performance

- **Fast tests** - mock slow operations
- **Parallel execution** - independent tests
- **Minimal setup** - only what's needed

## Debugging Tests

### Verbose Mode

```bash
# Detailed test output
./tests/run-tests.sh --verbose unit

# Debug specific test
DEBUG=1 bats tests/unit/test_utils.bats
```

### Manual Test Execution

```bash
# Run single test file
bats tests/unit/test_utils.bats

# Run specific test
bats -f "validate_directory" tests/unit/test_utils.bats

# With TAP output
bats --tap tests/unit/test_utils.bats
```

### Common Issues

1. **Module loading failures**
   ```bash
   # Check paths are correct
   echo "LIB_DIR: $LIB_DIR"
   ls -la lib/core/
   ```

2. **Permission errors**
   ```bash
   # Ensure executables are executable
   chmod +x bin/dji-processor tests/run-tests.sh
   ```

3. **Submodule issues**
   ```bash
   # Update submodules
   git submodule update --init --recursive
   ```

## Test Coverage

Current test coverage includes:

### ✅ Fully Tested
- Core utilities (platform detection, validation, formatting)
- Configuration loading and parsing
- Logging system (levels, colors, file output)
- CLI interface (commands, options, error handling)

### 🔄 Partial Coverage
- Video processing functions (mocked dependencies)
- Parallel processing logic
- File system operations

### ⏳ Planned
- Performance benchmarks
- Load testing with large file sets
- Cross-platform compatibility tests
- Memory usage profiling

## Contributing Tests

When adding new features:

1. **Write tests first** - TDD approach
2. **Test happy path and edge cases**
3. **Include integration tests** for CLI changes
4. **Update documentation** for new test patterns
5. **Ensure tests pass** before submitting PR

Example workflow:
```bash
# 1. Write test
echo '@test "new_function: should work correctly" { ... }' >> tests/unit/test_utils.bats

# 2. Run test (should fail)
make test-utils

# 3. Implement function
# 4. Run test (should pass)
make test-utils

# 5. Full test suite
make test
```

## Resources

- **BATS Documentation**: https://bats-core.readthedocs.io/
- **BATS GitHub**: https://github.com/bats-core/bats-core
- **Helper Libraries**:
  - [bats-support](https://github.com/bats-core/bats-support)
  - [bats-assert](https://github.com/bats-core/bats-assert) 
  - [bats-file](https://github.com/bats-core/bats-file)
- **TAP Format**: https://testanything.org/