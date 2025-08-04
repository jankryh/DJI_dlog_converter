#!/usr/bin/env bash

# Test runner script for DJI Video Processor
# Runs all BATS tests with proper setup and reporting

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test configuration
TEST_DIR="$SCRIPT_DIR"
UNIT_TESTS_DIR="$TEST_DIR/unit"
INTEGRATION_TESTS_DIR="$TEST_DIR/integration"
TEMP_DIR="$TEST_DIR/tmp"
REPORTS_DIR="$TEST_DIR/reports"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Show usage information
show_usage() {
    cat << 'EOF'
DJI Video Processor Test Runner

Usage: ./run-tests.sh [OPTIONS] [TEST_TYPE]

TEST_TYPES:
    unit            Run unit tests only
    integration     Run integration tests only  
    all             Run all tests (default)

OPTIONS:
    -v, --verbose   Verbose output
    -f, --filter    Filter tests by pattern (e.g., "test_utils")
    -t, --tap       Output in TAP format
    -j, --junit     Generate JUnit XML report
    -h, --help      Show this help

EXAMPLES:
    ./run-tests.sh                           # Run all tests
    ./run-tests.sh unit                      # Run unit tests only
    ./run-tests.sh --filter "test_config"   # Run config tests only
    ./run-tests.sh --tap                    # TAP output format
    ./run-tests.sh --junit integration      # Integration tests with JUnit report

EOF
}

# Parse command line arguments
parse_args() {
    VERBOSE=""
    FILTER=""
    TAP_OUTPUT=""
    JUNIT_REPORT=""
    TEST_TYPE="all"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE="--verbose-run"
                shift
                ;;
            -f|--filter)
                FILTER="$2"
                shift 2
                ;;
            -t|--tap)
                TAP_OUTPUT="--tap"
                shift
                ;;
            -j|--junit)
                JUNIT_REPORT="true"
                shift
                ;;
            unit|integration|all)
                TEST_TYPE="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Setup test environment
setup_test_env() {
    log_info "Setting up test environment..."
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Create necessary directories
    mkdir -p "$TEMP_DIR" "$REPORTS_DIR"
    
    # Clean previous test artifacts
    rm -rf "$TEMP_DIR"/*
    
    # Check BATS installation
    if ! command -v bats >/dev/null 2>&1; then
        log_error "BATS is not installed. Please install it first:"
        echo "  brew install bats-core"
        echo "  # or"
        echo "  npm install -g bats"
        exit 1
    fi
    
    # Check BATS helper modules
    if [[ ! -d "$TEST_DIR/test_helper/bats-support" ]]; then
        log_error "BATS helper modules not found. Run:"
        echo "  git submodule update --init --recursive"
        exit 1
    fi
    
    log_success "Test environment ready"
}

# Check project dependencies
check_dependencies() {
    log_info "Checking project dependencies..."
    
    local missing_deps=()
    
    # Check core files exist
    if [[ ! -f "$PROJECT_ROOT/bin/dji-processor" ]]; then
        missing_deps+=("bin/dji-processor")
    fi
    
    if [[ ! -f "$PROJECT_ROOT/lib/core/utils.sh" ]]; then
        missing_deps+=("lib/core/utils.sh")
    fi
    
    if [[ ! -f "$PROJECT_ROOT/lib/core/config.sh" ]]; then
        missing_deps+=("lib/core/config.sh")
    fi
    
    if [[ ! -f "$PROJECT_ROOT/lib/core/logging.sh" ]]; then
        missing_deps+=("lib/core/logging.sh")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing project files:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
    
    log_success "Project dependencies OK"
}

# Build BATS command
build_bats_command() {
    local test_files=()
    local bats_cmd="bats"
    
    # Add options
    if [[ -n "$VERBOSE" ]]; then
        bats_cmd="$bats_cmd $VERBOSE"
    fi
    
    if [[ -n "$TAP_OUTPUT" ]]; then
        bats_cmd="$bats_cmd $TAP_OUTPUT"
    fi
    
    # Select test files based on type and filter
    case "$TEST_TYPE" in
        unit)
            if [[ -n "$FILTER" ]]; then
                test_files=($(find "$UNIT_TESTS_DIR" -name "*${FILTER}*.bats" 2>/dev/null || true))
            else
                test_files=($(find "$UNIT_TESTS_DIR" -name "*.bats" 2>/dev/null || true))
            fi
            ;;
        integration)
            if [[ -n "$FILTER" ]]; then
                test_files=($(find "$INTEGRATION_TESTS_DIR" -name "*${FILTER}*.bats" 2>/dev/null || true))
            else
                test_files=($(find "$INTEGRATION_TESTS_DIR" -name "*.bats" 2>/dev/null || true))
            fi
            ;;
        all)
            if [[ -n "$FILTER" ]]; then
                test_files=($(find "$UNIT_TESTS_DIR" "$INTEGRATION_TESTS_DIR" -name "*${FILTER}*.bats" 2>/dev/null || true))
            else
                test_files=($(find "$UNIT_TESTS_DIR" "$INTEGRATION_TESTS_DIR" -name "*.bats" 2>/dev/null || true))
            fi
            ;;
    esac
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_error "No test files found for type '$TEST_TYPE' with filter '$FILTER'"
        exit 1
    fi
    
    echo "$bats_cmd ${test_files[*]}"
}

# Run tests
run_tests() {
    local bats_command
    bats_command=$(build_bats_command)
    
    log_info "Running $TEST_TYPE tests..."
    log_info "Command: $bats_command"
    echo ""
    
    # Run tests and capture output
    local start_time
    start_time=$(date +%s)
    
    local test_output
    local exit_code=0
    
    if [[ -n "$JUNIT_REPORT" ]]; then
        # Run with JUnit report generation
        test_output=$(eval "$bats_command --formatter junit" 2>&1) || exit_code=$?
        echo "$test_output" > "$REPORTS_DIR/junit-report.xml"
        echo "$test_output"
    else
        # Run with standard output
        eval "$bats_command" || exit_code=$?
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    log_info "Test execution completed in ${duration}s"
    
    return $exit_code
}

# Generate test report
generate_report() {
    local exit_code=$1
    
    log_info "Generating test report..."
    
    # Create simple text report
    local report_file="$REPORTS_DIR/test-report.txt"
    
    cat > "$report_file" << EOF
DJI Video Processor Test Report
Generated: $(date)
Test Type: $TEST_TYPE
Exit Code: $exit_code

Test Environment:
- BATS Version: $(bats --version)
- Platform: $(uname -s)
- Project Root: $PROJECT_ROOT

EOF
    
    if [[ $exit_code -eq 0 ]]; then
        echo "Result: PASSED ✅" >> "$report_file"
        log_success "All tests passed!"
    else
        echo "Result: FAILED ❌" >> "$report_file"
        log_error "Some tests failed!"
    fi
    
    echo ""
    log_info "Report saved to: $report_file"
    
    if [[ -n "$JUNIT_REPORT" ]]; then
        log_info "JUnit report saved to: $REPORTS_DIR/junit-report.xml"
    fi
}

# Cleanup function
cleanup() {
    # Clean temporary files
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"/*
    fi
}

# Main execution
main() {
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Parse arguments
    parse_args "$@"
    
    # Setup and run tests
    setup_test_env
    check_dependencies
    
    local exit_code=0
    run_tests || exit_code=$?
    
    generate_report $exit_code
    
    exit $exit_code
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi