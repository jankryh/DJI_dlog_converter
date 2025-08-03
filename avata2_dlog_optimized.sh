#!/bin/bash

# DJI Avata 2 D-Log to Rec.709 Video Processor - Optimized Version
# Processes DJI D-Log video files using hardware acceleration and LUT

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
# Default configuration file paths
CONFIG_FILE="${CONFIG_FILE:-./dji-config.yml}"
DEFAULT_CONFIG_FILE="$HOME/.dji-processor/config.yml"

# Default values (will be overridden by config file and command line)
SOURCE_DIR="/Users/onimalu/Movies/DJI/source"
FINAL_DIR="/Users/onimalu/Movies/DJI/final"
LUT_FILE="/Users/onimalu/Movies/DJI/Avata2.cube"
BAR_LENGTH=50
QUALITY_PRESET="high"  # high, medium, low
PARALLEL_JOBS="auto"   # auto, or specific number
AUTO_BACKUP=false
BACKUP_DIR="/Users/onimalu/Movies/DJI/backup"
SKIP_EXISTING=true
ORGANIZE_BY_DATE=false
DATE_FORMAT="%Y-%m-%d"
FORCE_ENCODER="auto"
CUSTOM_FFMPEG_ARGS=""
VERBOSE_LOGGING=false
LOG_FILE=""
KEEP_JOB_LOGS=false
MACOS_NOTIFICATIONS=true
COMPLETION_SOUND=true
MAX_CPU_USAGE=90
THERMAL_PROTECTION=true
MIN_FILE_SIZE=10
MAX_FILE_SIZE=0
PRESERVE_TIMESTAMPS=true
PRESERVE_METADATA=true
ADD_PROCESSING_METADATA=false

# Parallel processing variables
declare -a RUNNING_JOBS=()
declare -a JOB_FILES=()
JOB_COUNTER=0

# Configuration file parsing
parse_config_value() {
    local key="$1"
    local file="$2"
    local value
    
    # Extract value from YAML-like format, handling quotes and comments
    value=$(grep "^[[:space:]]*${key}:" "$file" 2>/dev/null | \
            sed 's/^[[:space:]]*[^:]*:[[:space:]]*//' | \
            sed 's/[[:space:]]*#.*$//' | \
            sed 's/^"\(.*\)"$/\1/' | \
            sed "s/^'\(.*\)'$/\1/" | \
            head -n1)
    
    echo "$value"
}

parse_config_bool() {
    local key="$1"
    local file="$2"
    local value
    
    value=$(parse_config_value "$key" "$file")
    # Convert to lowercase for bash 3.2 compatibility
    value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
    case "$value" in
        true|yes|1|on) echo "true" ;;
        false|no|0|off) echo "false" ;;
        *) echo "false" ;;
    esac
}

load_config_file() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # Validate config file is readable
    if [[ ! -r "$config_file" ]]; then
        handle_error "PERMISSION_ERROR" "Cannot read configuration file: $config_file"
    fi
    
    # Basic YAML syntax validation (if PyYAML is available)
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml" 2>/dev/null; then
            if ! python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
                handle_error "INVALID_CONFIG" "YAML syntax error in configuration file" "$config_file"
            fi
        fi
    fi
    
    log_info "📄 Loading configuration from: $config_file"
    
    # Parse configuration values
    local temp_value
    
    temp_value=$(parse_config_value "source_directory" "$config_file")
    [[ -n "$temp_value" ]] && SOURCE_DIR="$temp_value"
    
    temp_value=$(parse_config_value "output_directory" "$config_file")
    [[ -n "$temp_value" ]] && FINAL_DIR="$temp_value"
    
    temp_value=$(parse_config_value "lut_file" "$config_file")
    [[ -n "$temp_value" ]] && LUT_FILE="$temp_value"
    
    temp_value=$(parse_config_value "quality_preset" "$config_file")
    [[ -n "$temp_value" ]] && QUALITY_PRESET="$temp_value"
    
    temp_value=$(parse_config_value "parallel_jobs" "$config_file")
    [[ -n "$temp_value" ]] && PARALLEL_JOBS="$temp_value"
    
    temp_value=$(parse_config_bool "auto_backup" "$config_file")
    AUTO_BACKUP="$temp_value"
    
    temp_value=$(parse_config_value "backup_directory" "$config_file")
    [[ -n "$temp_value" ]] && BACKUP_DIR="$temp_value"
    
    temp_value=$(parse_config_bool "skip_existing" "$config_file")
    SKIP_EXISTING="$temp_value"
    
    temp_value=$(parse_config_bool "organize_by_date" "$config_file")
    ORGANIZE_BY_DATE="$temp_value"
    
    temp_value=$(parse_config_value "date_format" "$config_file")
    [[ -n "$temp_value" ]] && DATE_FORMAT="$temp_value"
    
    temp_value=$(parse_config_value "force_encoder" "$config_file")
    [[ -n "$temp_value" ]] && FORCE_ENCODER="$temp_value"
    
    temp_value=$(parse_config_value "custom_ffmpeg_args" "$config_file")
    [[ -n "$temp_value" ]] && CUSTOM_FFMPEG_ARGS="$temp_value"
    
    temp_value=$(parse_config_bool "verbose_logging" "$config_file")
    VERBOSE_LOGGING="$temp_value"
    
    temp_value=$(parse_config_value "log_file" "$config_file")
    [[ -n "$temp_value" ]] && LOG_FILE="$temp_value"
    
    temp_value=$(parse_config_bool "keep_job_logs" "$config_file")
    KEEP_JOB_LOGS="$temp_value"
    
    temp_value=$(parse_config_bool "macos_notifications" "$config_file")
    MACOS_NOTIFICATIONS="$temp_value"
    
    temp_value=$(parse_config_bool "completion_sound" "$config_file")
    COMPLETION_SOUND="$temp_value"
    
    temp_value=$(parse_config_value "max_cpu_usage" "$config_file")
    [[ -n "$temp_value" ]] && MAX_CPU_USAGE="$temp_value"
    
    temp_value=$(parse_config_bool "thermal_protection" "$config_file")
    THERMAL_PROTECTION="$temp_value"
    
    temp_value=$(parse_config_value "min_file_size" "$config_file")
    [[ -n "$temp_value" ]] && MIN_FILE_SIZE="$temp_value"
    
    temp_value=$(parse_config_value "max_file_size" "$config_file")
    [[ -n "$temp_value" ]] && MAX_FILE_SIZE="$temp_value"
    
    temp_value=$(parse_config_bool "preserve_timestamps" "$config_file")
    PRESERVE_TIMESTAMPS="$temp_value"
    
    temp_value=$(parse_config_bool "preserve_metadata" "$config_file")
    PRESERVE_METADATA="$temp_value"
    
    temp_value=$(parse_config_bool "add_processing_metadata" "$config_file")
    ADD_PROCESSING_METADATA="$temp_value"
    
    return 0
}

apply_config() {
    # Try to load configuration file
    if [[ -f "$CONFIG_FILE" ]]; then
        load_config_file "$CONFIG_FILE"
    elif [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        load_config_file "$DEFAULT_CONFIG_FILE"
    fi
    
    # Handle parallel jobs setting with validation
    if [[ "$PARALLEL_JOBS" == "auto" || "$PARALLEL_JOBS" == "0" ]]; then
        PARALLEL_JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo "2")
    elif ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ $PARALLEL_JOBS -lt 1 ]] || [[ $PARALLEL_JOBS -gt 32 ]]; then
        handle_error "INVALID_CONFIG" "Invalid parallel_jobs value: $PARALLEL_JOBS (must be 1-32 or 'auto')"
    fi
    

    
    # Apply command line overrides
    [[ -n "${1:-}" ]] && SOURCE_DIR="$1"
    [[ -n "${2:-}" ]] && FINAL_DIR="$2"
    [[ -n "${3:-}" ]] && LUT_FILE="$3"
    
    # Apply environment variable overrides (these override config file values)
    # Note: bash expansion ${VAR:-default} keeps existing value if VAR is set
    # We want to preserve environment variables even if config file sets different values
    
    # Re-validate after environment variable overrides
    if [[ "$PARALLEL_JOBS" != "auto" && "$PARALLEL_JOBS" != "0" ]]; then
        if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ $PARALLEL_JOBS -lt 1 ]] || [[ $PARALLEL_JOBS -gt 32 ]]; then
            handle_error "INVALID_CONFIG" "Invalid PARALLEL_JOBS environment variable: $PARALLEL_JOBS (must be 1-32 or 'auto')"
        fi
    fi
    
    case "$QUALITY_PRESET" in
        high|medium|low) ;;
        *) handle_error "INVALID_CONFIG" "Invalid QUALITY_PRESET value: $QUALITY_PRESET (must be 'high', 'medium', or 'low')" ;;
    esac
    
    # Final validation of all configuration values
    if [[ "$PARALLEL_JOBS" != "auto" && "$PARALLEL_JOBS" != "0" ]]; then
        if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ $PARALLEL_JOBS -lt 1 ]] || [[ $PARALLEL_JOBS -gt 32 ]]; then
            handle_error "INVALID_CONFIG" "Invalid parallel_jobs value: $PARALLEL_JOBS (must be 1-32 or 'auto')"
        fi
    fi
}

# Comprehensive validation for processing setup (used by dry-run and early validation)
validate_processing_setup() {
    log_info "🔍 Comprehensive Processing Validation"
    echo "======================================"
    
    local validation_errors=0
    local validation_warnings=0
    
    # Apply configuration with arguments
    apply_config "$@"
    
    echo ""
    log_info "📋 Configuration Summary:"
    echo "Source directory: $SOURCE_DIR"
    echo "Output directory: $FINAL_DIR"
    echo "LUT file: $LUT_FILE"
    echo "Quality preset: $QUALITY_PRESET"
    echo "Parallel jobs: $PARALLEL_JOBS"
    
    echo ""
    log_info "🔍 Validation Checks:"
    
    # 1. Validate source directory
    if [[ -d "$SOURCE_DIR" ]]; then
        log_success "✅ Source directory exists: $SOURCE_DIR"
        
        # Check if readable
        if [[ -r "$SOURCE_DIR" ]]; then
            log_success "✅ Source directory is readable"
        else
            log_error "❌ Source directory not readable: $SOURCE_DIR"
            ((validation_errors++))
        fi
        
        # Check for video files
        local video_count
        video_count=$(find "$SOURCE_DIR" -type f \( -iname "*.mp4" -o -iname "*.mov" \) 2>/dev/null | wc -l)
        if [[ $video_count -gt 0 ]]; then
            log_success "✅ Found $video_count video files to process"
        else
            log_warning "⚠️  No video files found in source directory"
            ((validation_warnings++))
        fi
    else
        log_error "❌ Source directory not found: $SOURCE_DIR"
        ((validation_errors++))
    fi
    
    # 2. Validate output directory
    if [[ -d "$FINAL_DIR" ]]; then
        log_success "✅ Output directory exists: $FINAL_DIR"
    else
        log_info "🔧 Output directory will be created: $FINAL_DIR"
        if mkdir -p "$FINAL_DIR" 2>/dev/null; then
            log_success "✅ Output directory created successfully"
            rmdir "$FINAL_DIR" 2>/dev/null  # Clean up test directory
        else
            log_error "❌ Cannot create output directory: $FINAL_DIR"
            ((validation_errors++))
        fi
    fi
    
    # Check write permissions for output directory
    if [[ -d "$FINAL_DIR" ]] && [[ -w "$FINAL_DIR" ]]; then
        log_success "✅ Output directory is writable"
    elif [[ -d "$FINAL_DIR" ]]; then
        log_error "❌ Output directory not writable: $FINAL_DIR"
        ((validation_errors++))
    fi
    
    # 3. Validate LUT file
    if [[ -f "$LUT_FILE" ]]; then
        log_success "✅ LUT file exists: $LUT_FILE"
        
        # Check if readable
        if [[ -r "$LUT_FILE" ]]; then
            log_success "✅ LUT file is readable"
            
            # Basic LUT file validation
            if [[ "$LUT_FILE" =~ \.cube$ ]]; then
                log_success "✅ LUT file has correct .cube extension"
                
                # Check file content
                if head -n 5 "$LUT_FILE" | grep -q "LUT_3D_SIZE\|TITLE" 2>/dev/null; then
                    log_success "✅ LUT file appears to be valid"
                else
                    log_warning "⚠️  LUT file format may be invalid (no standard headers found)"
                    ((validation_warnings++))
                fi
            else
                log_warning "⚠️  LUT file doesn't have .cube extension: $LUT_FILE"
                ((validation_warnings++))
            fi
        else
            log_error "❌ LUT file not readable: $LUT_FILE"
            ((validation_errors++))
        fi
    else
        log_error "❌ LUT file not found: $LUT_FILE"
        ((validation_errors++))
    fi
    
    # 4. Check disk space
    if [[ -d "$FINAL_DIR" ]] || mkdir -p "$FINAL_DIR" 2>/dev/null; then
        local available_space
        available_space=$(df "$FINAL_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
        if [[ -n "$available_space" ]]; then
            local space_gb=$((available_space / 1024 / 1024))
            local space_mb=$((available_space / 1024))
            
            if [[ $space_gb -ge 10 ]]; then
                log_success "✅ Sufficient disk space: ${space_gb}GB available"
            elif [[ $space_gb -ge 1 ]]; then
                log_success "✅ Adequate disk space: ${space_gb}GB available"
            elif [[ $space_mb -ge 500 ]]; then
                log_warning "⚠️  Limited disk space: ${space_mb}MB available"
                ((validation_warnings++))
            else
                log_error "❌ Insufficient disk space: ${space_mb}MB available (recommend at least 1GB)"
                ((validation_errors++))
            fi
        fi
    fi
    
    # 5. Validate dependencies
    check_dependencies
    
    # 6. Validate configuration values
    log_info "🔧 Configuration validation:"
    
    case "$QUALITY_PRESET" in
        high|medium|low)
            log_success "✅ Quality preset valid: $QUALITY_PRESET"
            ;;
        *)
            log_error "❌ Invalid quality preset: $QUALITY_PRESET"
            ((validation_errors++))
            ;;
    esac
    
    if [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] && [[ $PARALLEL_JOBS -ge 1 ]] && [[ $PARALLEL_JOBS -le 32 ]]; then
        log_success "✅ Parallel jobs setting valid: $PARALLEL_JOBS"
    elif [[ "$PARALLEL_JOBS" == "auto" ]]; then
        local detected_cores
        detected_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
        log_success "✅ Parallel jobs auto-detection: $detected_cores cores"
    else
        log_error "❌ Invalid parallel jobs setting: $PARALLEL_JOBS"
        ((validation_errors++))
    fi
    
    # 7. Estimate processing requirements
    if [[ $validation_errors -eq 0 && -d "$SOURCE_DIR" ]]; then
        echo ""
        log_info "📊 Processing Estimation:"
        
        local total_size=0
        local file_count=0
        local largest_file=0
        
        while IFS= read -r -d '' file; do
            if [[ -f "$file" ]]; then
                local file_size
                file_size=$(stat -f%z "$file" 2>/dev/null || echo "0")
                total_size=$((total_size + file_size))
                ((file_count++))
                if [[ $file_size -gt $largest_file ]]; then
                    largest_file=$file_size
                fi
            fi
        done < <(find "$SOURCE_DIR" -type f \( -iname "*.mp4" -o -iname "*.mov" \) -print0 2>/dev/null)
        
        if [[ $file_count -gt 0 ]]; then
            local total_gb=$((total_size / 1024 / 1024 / 1024))
            local total_mb=$((total_size / 1024 / 1024))
            local largest_mb=$((largest_file / 1024 / 1024))
            
            echo "Files to process: $file_count"
            if [[ $total_gb -gt 0 ]]; then
                echo "Total size: ${total_gb}GB"
            else
                echo "Total size: ${total_mb}MB"
            fi
            echo "Largest file: ${largest_mb}MB"
            
            # Estimate processing time (very rough)
            local est_minutes=$((total_mb / 100))  # Rough estimate: 100MB per minute
            if [[ $est_minutes -gt 60 ]]; then
                local est_hours=$((est_minutes / 60))
                local rem_minutes=$((est_minutes % 60))
                echo "Estimated time: ~${est_hours}h ${rem_minutes}m (approximate)"
            else
                echo "Estimated time: ~${est_minutes}m (approximate)"
            fi
        fi
    fi
    
    # 8. Summary
    echo ""
    log_info "📋 Validation Summary:"
    if [[ $validation_errors -eq 0 ]]; then
        if [[ $validation_warnings -eq 0 ]]; then
            log_success "🎉 All validation checks passed! Ready to process."
        else
            log_warning "⚠️  Validation completed with $validation_warnings warning(s). Processing should work but review warnings above."
        fi
        log_info "💡 To start processing, run without --dry-run flag"
        exit 0
    else
        log_error "💥 Validation failed with $validation_errors error(s) and $validation_warnings warning(s)"
        log_info "💡 Fix the errors above before attempting to process files"
        exit 1
    fi
}

# Early validation function (quick checks before starting main processing)
validate_early() {
    local quick_errors=0
    
    # Quick existence checks
    [[ -d "$SOURCE_DIR" ]] || ((quick_errors++))
    [[ -f "$LUT_FILE" ]] || ((quick_errors++))
    
    # Quick configuration checks
    case "$QUALITY_PRESET" in
        high|medium|low) ;;
        *) ((quick_errors++)) ;;
    esac
    
    if [[ "$PARALLEL_JOBS" != "auto" ]]; then
        [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] && [[ $PARALLEL_JOBS -ge 1 ]] && [[ $PARALLEL_JOBS -le 32 ]] || ((quick_errors++))
    fi
    
    # Quick dependency check
    command -v ffmpeg >/dev/null 2>&1 || ((quick_errors++))
    command -v ffprobe >/dev/null 2>&1 || ((quick_errors++))
    
    if [[ $quick_errors -gt 0 ]]; then
        log_warning "⚠️  Quick validation found potential issues. Running comprehensive validation..."
        validate_inputs  # This will provide detailed error messages
    fi
}

# Quality presets (bash 3.2 compatible)
get_quality_settings() {
    case "$1" in
        high)   echo "-b:v 15M -maxrate 18M -bufsize 30M" ;;
        medium) echo "-b:v 10M -maxrate 12M -bufsize 20M" ;;
        low)    echo "-b:v 6M -maxrate 8M -bufsize 12M" ;;
        *)      echo "-b:v 10M -maxrate 12M -bufsize 20M" ;;  # default to medium
    esac
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Utility functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}" >&2; }

# Check dependencies with enhanced error handling
check_dependencies() {
    local missing_deps=()
    
    if ! command -v ffmpeg >/dev/null 2>&1; then
        missing_deps+=("ffmpeg")
    fi
    
    if ! command -v ffprobe >/dev/null 2>&1; then
        missing_deps+=("ffprobe")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        for dep in "${missing_deps[@]}"; do
            handle_error "MISSING_DEPENDENCY" "$dep"
        done
    fi
    
    # Additional checks for optimal performance
    if command -v ffmpeg >/dev/null 2>&1; then
        local ffmpeg_version
        ffmpeg_version=$(ffmpeg -version 2>/dev/null | head -n1 | grep -o 'version [0-9.]*' | cut -d' ' -f2)
        log_info "✅ FFmpeg version $ffmpeg_version found"
        
        # Check for common encoding libraries
        if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libx264; then
            log_info "✅ x264 encoder available"
        else
            log_warning "⚠️  x264 encoder not found - limited encoding options"
        fi
    fi
}

# Enhanced error handling system
handle_error() {
    local error_code="$1"
    local error_message="$2"
    local context="${3:-}"
    local suggestion="${4:-}"
    
    case "$error_code" in
        MISSING_SOURCE_DIR)
            log_error "Source directory not found: $error_message"
            if [[ -n "$suggestion" ]]; then
                log_info "💡 $suggestion"
            else
                log_info "💡 Create the directory or update your configuration:"
                log_info "   mkdir -p \"$error_message\""
                log_info "   or edit dji-config.yml and set source_directory"
            fi
            ;;
        MISSING_LUT_FILE)
            log_error "LUT file not found: $error_message"
            log_info "💡 Possible solutions:"
            log_info "   1. Download a LUT file for your DJI drone"
            log_info "   2. Copy your LUT file to: $error_message"
            log_info "   3. Update the lut_file path in your configuration"
            ;;
        MISSING_OUTPUT_DIR)
            log_error "Cannot create output directory: $error_message"
            log_info "💡 Check directory permissions and available disk space"
            ;;
        INVALID_CONFIG)
            log_error "Configuration error: $error_message"
            if [[ -n "$context" ]]; then
                log_info "📄 In file: $context"
            fi
            log_info "💡 Run './avata2_dlog_optimized.sh config --validate' to check your configuration"
            ;;
        MISSING_DEPENDENCY)
            log_error "Missing required dependency: $error_message"
            case "$error_message" in
                ffmpeg)
                    log_info "💡 Install FFmpeg:"
                    log_info "   macOS: brew install ffmpeg"
                    log_info "   Linux: sudo apt-get install ffmpeg"
                    ;;
                *)
                    log_info "💡 Please install $error_message and try again"
                    ;;
            esac
            ;;
        INSUFFICIENT_SPACE)
            log_error "Insufficient disk space: $error_message"
            log_info "💡 Free up disk space or choose a different output directory"
            ;;
        PERMISSION_ERROR)
            log_error "Permission denied: $error_message"
            log_info "💡 Check file/directory permissions or run with appropriate privileges"
            ;;
        *)
            log_error "$error_message"
            [[ -n "$suggestion" ]] && log_info "💡 $suggestion"
            ;;
    esac
    
    exit 1
}

# Validate inputs with enhanced error handling
validate_inputs() {
    local errors=0
    
    # Validate source directory
    if [[ ! -d "$SOURCE_DIR" ]]; then
        handle_error "MISSING_SOURCE_DIR" "$SOURCE_DIR"
    fi
    
    # Validate LUT file
    if [[ ! -f "$LUT_FILE" ]]; then
        handle_error "MISSING_LUT_FILE" "$LUT_FILE"
    fi
    
    # Validate output directory is writable
    if [[ ! -d "$FINAL_DIR" ]]; then
        if ! mkdir -p "$FINAL_DIR" 2>/dev/null; then
            handle_error "MISSING_OUTPUT_DIR" "$FINAL_DIR"
        fi
    elif [[ ! -w "$FINAL_DIR" ]]; then
        handle_error "PERMISSION_ERROR" "Cannot write to output directory: $FINAL_DIR"
    fi
    
    # Check available disk space (at least 1GB free)
    local available_space
    available_space=$(df "$FINAL_DIR" | awk 'NR==2 {print $4}')
    if [[ -n "$available_space" && $available_space -lt 1048576 ]]; then
        local space_mb=$((available_space / 1024))
        handle_error "INSUFFICIENT_SPACE" "Only ${space_mb}MB available in output directory (recommend at least 1GB)"
    fi
    
    # Check if videotoolbox is available
    if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q h264_videotoolbox; then
        log_warning "Hardware acceleration (videotoolbox) not available, falling back to software encoding"
        log_info "💡 Software encoding will be slower but still functional"
        ENCODER="libx264"
        HWACCEL=""
    else
        log_info "✅ Hardware acceleration (VideoToolbox) available"
        ENCODER="h264_videotoolbox"
        HWACCEL="-hwaccel videotoolbox"
    fi
}

# Parallel processing functions
cleanup_jobs() {
    # Kill any remaining background jobs
    for pid in "${RUNNING_JOBS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    RUNNING_JOBS=()
    JOB_FILES=()
}

wait_for_job_slot() {
    # Wait until we have fewer than PARALLEL_JOBS running
    while [[ ${#RUNNING_JOBS[@]} -ge $PARALLEL_JOBS ]]; do
        check_completed_jobs
        [[ ${#RUNNING_JOBS[@]} -ge $PARALLEL_JOBS ]] && sleep 0.5
    done
}

check_completed_jobs() {
    local new_running_jobs=()
    local new_job_files=()
    
    for i in "${!RUNNING_JOBS[@]}"; do
        local pid="${RUNNING_JOBS[$i]}"
        local file="${JOB_FILES[$i]}"
        
        if kill -0 "$pid" 2>/dev/null; then
            # Job still running
            new_running_jobs+=("$pid")
            new_job_files+=("$file")
        else
            # Job completed, check exit status
            if wait "$pid"; then
                log_success "✅ Completed: $(basename "$file")"
                ((PROCESSED_COUNT++))
            else
                log_error "❌ Error: $(basename "$file")"
                ((FAILED_COUNT++))
            fi
        fi
    done
    
    RUNNING_JOBS=("${new_running_jobs[@]}")
    JOB_FILES=("${new_job_files[@]}")
}

wait_for_all_jobs() {
    # Wait for all remaining jobs to complete
    while [[ ${#RUNNING_JOBS[@]} -gt 0 ]]; do
        check_completed_jobs
        [[ ${#RUNNING_JOBS[@]} -gt 0 ]] && sleep 1
    done
}

start_parallel_job() {
    local input_file="$1"
    local job_id=$((++JOB_COUNTER))
    
    log_info "🚀 Starting job #$job_id: $(basename "$input_file")"
    
    # Start background job
    process_file_parallel "$input_file" "$job_id" &
    local pid=$!
    
    RUNNING_JOBS+=("$pid")
    JOB_FILES+=("$input_file")
}

show_parallel_status() {
    local total_files=$1
    local completed=$((PROCESSED_COUNT + FAILED_COUNT))
    local running=${#RUNNING_JOBS[@]}
    
    echo -ne "\r\033[K"
    printf "📊 Status: %d/%d completed | %d running | %d successful | %d errors" \
           "$completed" "$total_files" "$running" "$PROCESSED_COUNT" "$FAILED_COUNT"
}

# Get estimated time remaining and speed info
calculate_eta_and_speed() {
    local current_time=$1
    local duration=$2
    local start_time=$3
    
    local elapsed=$(($(date +%s) - start_time))
    
    # Show initial message
    if [[ $elapsed -le 5 ]]; then
        printf " | Starting..."
        return
    fi
    
    # Calculate speed and ETA after 5 seconds
    if [[ $current_time -gt 0 && $elapsed -gt 5 ]]; then
        # Calculate encoding speed (how much video processed per real second)
        local speed=$((current_time * 10 / elapsed))  # speed * 10 for precision
        local speed_display=$((speed / 10))
        local speed_decimal=$((speed % 10))
        
        # Calculate ETA with better precision
        local rate=$((current_time * 100 / elapsed))  # rate * 100
        if [[ $rate -gt 0 ]]; then
            local remaining=$((duration - current_time))
            local eta=$((remaining * 100 / rate))  # compensate for rate * 100
            
            if [[ $eta -gt 0 && $eta -lt 7200 ]]; then  # Max 2 hours ETA
                local eta_min=$((eta / 60))
                local eta_sec=$((eta % 60))
                printf " | %d.%dx | ETA: %02d:%02d" "$speed_display" "$speed_decimal" "$eta_min" "$eta_sec"
            else
                printf " | %d.%dx | Calculating ETA..." "$speed_display" "$speed_decimal"
            fi
        fi
    else
        printf " | Initializing..."
    fi
}

# Enhanced progress bar with ETA
show_progress() {
    local current_time=$1
    local duration=$2
    local basename=$3
    local start_time=$4
    
    local progress=$((current_time * 100 / duration))
    [[ $progress -gt 100 ]] && progress=100
    
    local filled=$((BAR_LENGTH * progress / 100))
    local empty=$((BAR_LENGTH - filled))
    
    local filled_bar=$(printf "%0.s#" $(seq 1 $filled 2>/dev/null || printf ""))
    local empty_bar=$(printf "%0.s-" $(seq 1 $empty 2>/dev/null || printf ""))
    
    local eta_info
    eta_info=$(calculate_eta_and_speed "$current_time" "$duration" "$start_time")
    
    # Clear line and display progress with better formatting
    printf "\r\033[K🔄 [%s%s] %3d%% %s%s" "$filled_bar" "$empty_bar" "$progress" "$basename" "$eta_info"
}

# Process single file
process_file() {
    local input_file="$1"
    local basename
    basename=$(basename "$input_file")
    local output_file="$FINAL_DIR/$basename"
    local temp_file="$output_file.tmp"
    
    # Determine output path (with date organization if enabled)
    local final_output_dir="$FINAL_DIR"
    if [[ "$ORGANIZE_BY_DATE" == "true" ]]; then
        local file_date
        file_date=$(stat -f "%Sm" -t "$DATE_FORMAT" "$input_file" 2>/dev/null || date +"$DATE_FORMAT")
        final_output_dir="$FINAL_DIR/$file_date"
        mkdir -p "$final_output_dir"
    fi
    
    output_file="$final_output_dir/$basename"
    temp_file="$output_file.tmp"
    
    # Skip if already exists and skip_existing is enabled
    if [[ "$SKIP_EXISTING" == "true" && -f "$output_file" ]]; then
        log_info "⏭️ Skipping (already exists): $basename"
        return 0
    fi
    
    # Create backup if enabled
    if [[ "$AUTO_BACKUP" == "true" ]]; then
        local backup_path="$BACKUP_DIR/$(basename "$input_file")"
        if [[ ! -f "$backup_path" ]]; then
            [[ "$VERBOSE_LOGGING" == "true" ]] && log_info "💾 Creating backup: $backup_path"
            cp "$input_file" "$backup_path" || log_warning "Failed to create backup for $basename"
        fi
    fi
    
    # Get duration with enhanced error handling
    local duration
    if ! duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null); then
        log_error "Cannot read video file: $basename"
        log_info "💡 Possible issues:"
        log_info "   1. File is corrupted or incomplete"
        log_info "   2. Unsupported video format"
        log_info "   3. File permissions issue"
        log_info "   Try: ffprobe -i \"$input_file\" to see detailed error information"
        return 1
    fi
    
    if [[ -z "$duration" || "$duration" == "N/A" ]]; then
        log_error "Cannot determine video duration: $basename"
        log_info "💡 This might be a corrupted or unsupported video file"
        return 1
    fi
    
    local duration_int
    printf -v duration_int "%.0f" "$duration"
    
    log_info "🎞️ Processing: $basename – duration: ${duration_int}s (quality: $QUALITY_PRESET)"
    
    local start_time
    start_time=$(date +%s)
    
    # Determine encoder to use
    local final_encoder="$ENCODER"
    if [[ "$FORCE_ENCODER" != "auto" ]]; then
        final_encoder="$FORCE_ENCODER"
        [[ "$VERBOSE_LOGGING" == "true" ]] && log_info "🔧 Using forced encoder: $final_encoder"
    fi
    
    # Build FFmpeg command with error handling
    local ffmpeg_cmd=(
        ffmpeg -hide_banner -loglevel error -progress pipe:1
        -nostdin
        $HWACCEL -i "$input_file"
        -vf "lut3d='${LUT_FILE}'"
        -c:v "$final_encoder" $(get_quality_settings "$QUALITY_PRESET")
        -c:a copy
    )
    
    # Add metadata preservation if enabled
    if [[ "$PRESERVE_METADATA" == "true" ]]; then
        ffmpeg_cmd+=(-map_metadata 0)
    fi
    
    # Add custom FFmpeg arguments if specified
    if [[ -n "$CUSTOM_FFMPEG_ARGS" ]]; then
        # Split custom args and add to command
        read -ra custom_args <<< "$CUSTOM_FFMPEG_ARGS"
        ffmpeg_cmd+=("${custom_args[@]}")
    fi
    
    # Add processing metadata if enabled
    if [[ "$ADD_PROCESSING_METADATA" == "true" ]]; then
        ffmpeg_cmd+=(-metadata "processed_by=DJI-Avata2-Processor")
        ffmpeg_cmd+=(-metadata "processing_date=$(date -Iseconds)")
        ffmpeg_cmd+=(-metadata "quality_preset=$QUALITY_PRESET")
    fi
    
    ffmpeg_cmd+=(
        -f mp4  # Explicitly specify MP4 format for .tmp files
        -movflags +faststart  # Optimize for streaming
        -y "$temp_file"
    )
    
    # Process with progress tracking
    if "${ffmpeg_cmd[@]}" | while IFS= read -r line; do
        local current_time=""
        
        # Parse time from ffmpeg progress output
        if [[ "$line" =~ out_time_us=([0-9]+) ]]; then
            current_time=$((${BASH_REMATCH[1]} / 1000000))
        elif [[ "$line" =~ time=([0-9]+):([0-9]+):([0-9]+)\.([0-9]+) ]]; then
            local h=$((10#${BASH_REMATCH[1]}))
            local m=$((10#${BASH_REMATCH[2]}))
            local s=$((10#${BASH_REMATCH[3]}))
            current_time=$((h * 3600 + m * 60 + s))
        elif [[ "$line" =~ time=([0-9]+)\.([0-9]+) ]]; then
            current_time=${BASH_REMATCH[1]}
        fi
        
        # Update progress bar
        if [[ -n "$current_time" && $current_time -gt 0 ]]; then
            show_progress "$current_time" "$duration_int" "$basename" "$start_time"
        fi
    done; then
        # Success - move temp file to final location
        mv "$temp_file" "$output_file"
        echo ""  # New line after progress bar
        
        # Calculate processing time
        local end_time
        end_time=$(date +%s)
        local processing_time=$((end_time - start_time))
        local proc_min=$((processing_time / 60))
        local proc_sec=$((processing_time % 60))
        
        # Show file size info
        local size
        size=$(du -h "$output_file" | cut -f1)
        
        # Preserve timestamps if enabled
        if [[ "$PRESERVE_TIMESTAMPS" == "true" ]]; then
            touch -r "$input_file" "$output_file"
        fi
        
        log_success "Completed: $basename"
        log_info "Size: $size | Time: $(printf "%02d:%02d" "$proc_min" "$proc_sec")"
    else
        # Error - cleanup temp file and provide helpful information
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
        echo ""  # New line after progress bar
        log_error "Error processing: $basename"
        
        # Provide helpful debugging information
        log_info "💡 Troubleshooting steps:"
        log_info "   1. Check that the LUT file is valid: $LUT_FILE"
        log_info "   2. Verify sufficient disk space in output directory"
        log_info "   3. Try with a different quality preset (QUALITY_PRESET=medium)"
        log_info "   4. Check the source file isn't corrupted"
        
        # Suggest running with verbose mode
        if [[ "$VERBOSE_LOGGING" != "true" ]]; then
            log_info "   5. Enable verbose logging to see detailed error information:"
            log_info "      VERBOSE_LOGGING=true ./avata2_dlog_optimized.sh"
        fi
        
        return 1
    fi
}

# Process single file for parallel execution (simplified progress)
process_file_parallel() {
    local input_file="$1"
    local job_id="$2"
    local basename
    basename=$(basename "$input_file")
    local output_file="$FINAL_DIR/$basename"
    local temp_file="$output_file.tmp"
    local log_file="/tmp/dji_job_${job_id}_$$.log"
    
    # Skip if already exists
    if [[ -f "$output_file" ]]; then
        echo "⏭️ Skipping (already exists): $basename" > "$log_file"
        return 0
    fi
    
    # Get duration
    local duration
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)
    if [[ -z "$duration" || "$duration" == "N/A" ]]; then
        echo "❌ Cannot determine video duration: $basename" > "$log_file"
        return 1
    fi
    
    local duration_int
    printf -v duration_int "%.0f" "$duration"
    
    echo "🎞️ Processing job #$job_id: $basename – duration: ${duration_int}s (quality: $QUALITY_PRESET)" > "$log_file"
    
    local start_time
    start_time=$(date +%s)
    
    # FFmpeg command with error handling
    local ffmpeg_cmd=(
        ffmpeg -hide_banner -loglevel error
        -nostdin
        $HWACCEL -i "$input_file"
        -vf "lut3d='${LUT_FILE}'"
        -c:v "$ENCODER" $(get_quality_settings "$QUALITY_PRESET")
        -c:a copy
        -f mp4  # Explicitly specify MP4 format for .tmp files
        -movflags +faststart  # Optimize for streaming
        -y "$temp_file"
    )
    
    # Process without progress tracking (for parallel execution)
    if "${ffmpeg_cmd[@]}" 2>>"$log_file"; then
        # Success - move temp file to final location
        mv "$temp_file" "$output_file"
        
        # Calculate processing time
        local end_time
        end_time=$(date +%s)
        local processing_time=$((end_time - start_time))
        local proc_min=$((processing_time / 60))
        local proc_sec=$((processing_time % 60))
        
        # Show file size info
        local size
        size=$(du -h "$output_file" | cut -f1)
        
        echo "✅ Completed job #$job_id: $basename" >> "$log_file"
        echo "Size: $size | Time: $(printf "%02d:%02d" "$proc_min" "$proc_sec")" >> "$log_file"
        
        # Preserve timestamps if enabled
        if [[ "$PRESERVE_TIMESTAMPS" == "true" ]]; then
            touch -r "$input_file" "$output_file"
        fi
        
        # Cleanup log file based on configuration
        if [[ "$KEEP_JOB_LOGS" != "true" ]]; then
            rm -f "$log_file"
        fi
        return 0
    else
        # Error - cleanup temp file
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
        echo "❌ Error processing job #$job_id: $basename" >> "$log_file"
        
        # Keep log file for debugging
        return 1
    fi
}

# Main execution
main() {
    # Apply configuration first
    apply_config "$@"
    
    # Run early validation to catch issues before processing starts
    validate_early
    
    log_info "🚀 DJI Avata 2 D-Log Processor (Optimized) - Parallel Edition"
    log_info "Source directory: $SOURCE_DIR"
    log_info "Output directory: $FINAL_DIR"
    log_info "LUT file: $LUT_FILE"
    log_info "Quality: $QUALITY_PRESET"
    log_info "Parallel jobs: $PARALLEL_JOBS"
    
    # Show additional configuration if verbose
    if [[ "$VERBOSE_LOGGING" == "true" ]]; then
        log_info "🔧 Configuration details:"
        log_info "   Auto backup: $AUTO_BACKUP"
        log_info "   Skip existing: $SKIP_EXISTING"
        log_info "   Organize by date: $ORGANIZE_BY_DATE"
        log_info "   Preserve metadata: $PRESERVE_METADATA"
        log_info "   Min file size: ${MIN_FILE_SIZE}MB"
        [[ "$MAX_FILE_SIZE" -gt 0 ]] && log_info "   Max file size: ${MAX_FILE_SIZE}GB"
    fi
    
    check_dependencies
    validate_inputs
    
    mkdir -p "$FINAL_DIR"
    
    # Create backup directory if needed
    if [[ "$AUTO_BACKUP" == "true" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_info "💾 Auto backup enabled: $BACKUP_DIR"
    fi
    
    # Find video files based on configuration
    FILES=()
    local temp_file_list="/tmp/dji_files_$$.tmp"
    
    # Simple approach: find common video file extensions
    # Default extensions
    local extensions=("mp4" "MP4" "mov" "MOV")
    
    # Parse extensions from config file if available
    local config_to_use=""
    [[ -f "$CONFIG_FILE" ]] && config_to_use="$CONFIG_FILE"
    [[ -f "$DEFAULT_CONFIG_FILE" && -z "$config_to_use" ]] && config_to_use="$DEFAULT_CONFIG_FILE"
    
    if [[ -n "$config_to_use" ]] && grep -q "^file_extensions:" "$config_to_use"; then
        # Extract extensions from config file
        extensions=()
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\"(.+)\"$ ]]; then
                extensions+=("${BASH_REMATCH[1]}")
            elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*([^\"[:space:]#]+)$ ]]; then
                extensions+=("${BASH_REMATCH[1]}")
            fi
        done < <(sed -n '/^file_extensions:/,/^[[:alpha:]]/p' "$config_to_use" | tail -n +2)
    fi
    
    # Build and execute find command
    > "$temp_file_list"  # Create empty file
    for ext in "${extensions[@]}"; do
        find "$SOURCE_DIR" -type f -iname "*.${ext}" 2>/dev/null >> "$temp_file_list"
    done
    
    # Sort the results
    sort -u "$temp_file_list" -o "$temp_file_list"
    
    # Filter files by size and other criteria
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        # Check file size constraints
        local file_size_mb
        file_size_mb=$(du -m "$file" 2>/dev/null | cut -f1)
        
        # Skip files that are too small
        if [[ ${file_size_mb:-0} -lt $MIN_FILE_SIZE ]]; then
            [[ "$VERBOSE_LOGGING" == "true" ]] && log_info "⏭️ Skipping (too small: ${file_size_mb}MB): $(basename "$file")"
            continue
        fi
        
        # Skip files that are too large
        if [[ $MAX_FILE_SIZE -gt 0 ]]; then
            local file_size_gb=$((file_size_mb / 1024))
            if [[ $file_size_gb -gt $MAX_FILE_SIZE ]]; then
                [[ "$VERBOSE_LOGGING" == "true" ]] && log_info "⏭️ Skipping (too large: ${file_size_gb}GB): $(basename "$file")"
                continue
            fi
        fi
        
        FILES[${#FILES[@]}]="$file"
    done < "$temp_file_list"
    rm -f "$temp_file_list"
    
    local total=${#FILES[@]}
    
    if [[ $total -eq 0 ]]; then
        log_warning "No MP4 files found in: $SOURCE_DIR"
        exit 0
    fi
    
    log_info "Found $total files to process"
    
    # Initialize parallel processing counters
    PROCESSED_COUNT=0
    FAILED_COUNT=0
    
    # Record total processing start time
    local total_start_time
    total_start_time=$(date +%s)
    
    # Process files with parallel execution
    if [[ $PARALLEL_JOBS -eq 1 ]]; then
        # Sequential processing (original behavior)
        log_info "🔄 Sequential processing (1 job at a time)"
        for i in "${!FILES[@]}"; do
            local input_file="${FILES[$i]}"
            log_info "📁 File $((i+1))/$total"
            
            if process_file "$input_file"; then
                ((PROCESSED_COUNT++))
            else
                ((FAILED_COUNT++))
            fi
        done
    else
        # Parallel processing
        log_info "🚀 Parallel processing ($PARALLEL_JOBS jobs simultaneously)"
        
        # Start initial jobs
        for i in "${!FILES[@]}"; do
            wait_for_job_slot
            start_parallel_job "${FILES[$i]}"
            
            # Show status every few jobs
            if [[ $((i % 3)) -eq 0 ]]; then
                show_parallel_status "$total"
            fi
        done
        
        # Wait for all jobs to complete
        echo ""
        log_info "⏳ Waiting for all jobs to complete..."
        wait_for_all_jobs
        echo ""
    fi
    
    # Calculate total processing time
    local total_end_time
    total_end_time=$(date +%s)
    local total_processing_time=$((total_end_time - total_start_time))
    local total_min=$((total_processing_time / 60))
    local total_sec=$((total_processing_time % 60))
    
    # Summary
    echo ""
    log_success "🏁 Processing completed!"
    log_info "✅ Successfully processed: $PROCESSED_COUNT"
    [[ $FAILED_COUNT -gt 0 ]] && log_warning "❌ Errors: $FAILED_COUNT"
    log_info "⏱️  Total time: $(printf "%02d:%02d" "$total_min" "$total_sec")"
    
    # Show performance info for parallel processing
    if [[ $PARALLEL_JOBS -gt 1 && $PROCESSED_COUNT -gt 0 ]]; then
        local avg_time_per_file=$((total_processing_time / PROCESSED_COUNT))
        local theoretical_sequential=$((avg_time_per_file * PROCESSED_COUNT))
        local speedup_factor=$((theoretical_sequential * 100 / total_processing_time))
        log_info "🚀 Speedup: ~$((speedup_factor / 100)).$((speedup_factor % 100))x thanks to parallelization"
    fi
    
    # Send notifications if enabled
    if [[ "$MACOS_NOTIFICATIONS" == "true" ]]; then
        local message="Processing completed! $PROCESSED_COUNT files processed"
        [[ $FAILED_COUNT -gt 0 ]] && message="$message, $FAILED_COUNT errors"
        osascript -e "display notification \"$message\" with title \"DJI Video Processor\"" 2>/dev/null || true
    fi
    
    # Play completion sound if enabled
    if [[ "$COMPLETION_SOUND" == "true" ]]; then
        afplay /System/Library/Sounds/Glass.aiff 2>/dev/null || true
    fi
}

# Handle interruption gracefully
trap 'echo ""; log_warning "Processing interrupted by user"; cleanup_jobs; exit 130' INT TERM

# Command parsing and routing
parse_command() {
    local command="${1:-}"
    
    # Check for help flags first
    if [[ "$command" =~ ^(-h|--help)$ ]]; then
        show_general_help
        exit 0
    fi
    
    # Detect if first argument is a subcommand
    case "$command" in
        process)
            shift
            command_process "$@"
            ;;
        status)
            shift
            command_status "$@"
            ;;
        config)
            shift
            command_config "$@"
            ;;
        validate)
            shift
            command_validate "$@"
            ;;
        help)
            shift
            command_help "$@"
            ;;
        completion)
            shift
            command_completion "$@"
            ;;
        "")
            # No arguments - use default behavior (process)
            command_process "$@"
            ;;
        *)
            # Check if it looks like an old-style positional argument (path)
            if [[ -d "$command" || "$command" =~ ^/ || "$command" =~ ^\. ]]; then
                log_info "📄 Using legacy argument format (backward compatibility)"
                command_process "$@"
            else
                log_error "Unknown command: $command"
                echo ""
                suggest_command "$command"
                echo ""
                log_info "💡 Run './avata2_dlog_optimized.sh help' for available commands"
                exit 1
            fi
            ;;
    esac
}

# Command suggestion system for typos
suggest_command() {
    local input="$1"
    local commands=("process" "status" "config" "validate" "help")
    local best_match=""
    local min_distance=999
    
    for cmd in "${commands[@]}"; do
        local distance=$(string_similarity "$input" "$cmd")
        if [[ $distance -lt $min_distance && $distance -le 2 ]]; then
            min_distance=$distance
            best_match="$cmd"
        fi
    done
    
    if [[ -n "$best_match" ]]; then
        log_info "💡 Did you mean: './avata2_dlog_optimized.sh $best_match'?"
    fi
}

# Simple string similarity for command suggestions
string_similarity() {
    local str1="$1"
    local str2="$2"
    local len1=${#str1}
    local len2=${#str2}
    
    # If one string is much longer than the other, it's probably not a match
    local len_diff=$((len1 > len2 ? len1 - len2 : len2 - len1))
    if [[ $len_diff -gt 3 ]]; then
        echo 99
        return
    fi
    
    # Check for substring match (common typos)
    if [[ "$str2" == *"$str1"* ]] || [[ "$str1" == *"$str2"* ]]; then
        echo 1
        return
    fi
    
    # Check for common single character errors (insertion, deletion, substitution)
    local min_len=$((len1 < len2 ? len1 : len2))
    if [[ $len_diff -le 1 ]]; then
        local common_chars=0
        for ((i=0; i<min_len; i++)); do
            if [[ "${str1:$i:1}" == "${str2:$i:1}" ]]; then
                ((common_chars++))
            fi
        done
        
        # If most characters match, it's likely a typo
        if [[ $common_chars -ge $((min_len - 2)) ]]; then
            echo 1
            return
        fi
    fi
    
    # Count character differences  
    local diff=0
    local max_len=$((len1 > len2 ? len1 : len2))
    
    # Add length difference
    diff=$((max_len - min_len))
    
    # Compare characters
    for ((i=0; i<min_len; i++)); do
        if [[ "${str1:$i:1}" != "${str2:$i:1}" ]]; then
            ((diff++))
        fi
    done
    
    echo $diff
}

# General help function
show_general_help() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

DJI Avata 2 D-Log to Rec.709 Video Processor with parallel processing and configuration support

COMMANDS:
  process     Process videos (default command)
  status      Show current processing status
  config      Manage configuration
  validate    Validate setup and files
  help        Show help for specific commands
  completion  Generate bash completion script

LEGACY USAGE (backward compatible):
  $0 [SOURCE_DIRECTORY] [OUTPUT_DIRECTORY] [LUT_FILE]

GLOBAL OPTIONS:
  -h, --help  Show this help message

Configuration Files:
  $0 looks for configuration in the following order:
  1. ./dji-config.yml (current directory)
  2. ~/.dji-processor/config.yml (user home directory)
  
  Environment variables:
    CONFIG_FILE      Path to custom configuration file

Environment variables:
  QUALITY_PRESET   Quality: high, medium, low (default: high)
  PARALLEL_JOBS    Number of parallel jobs (default: auto-detect CPU cores)

Examples:
  $0                                    # Process with config defaults
  $0 process                            # Explicit process command
  $0 status                             # Show current status
  $0 config --setup-wizard              # Interactive configuration
  $0 validate                           # Validate current setup
  $0 help process                       # Help for specific command
  
  # Legacy format (still supported):
  $0 /path/to/source /path/to/output    # Override paths from config
  QUALITY_PRESET=medium $0              # Override quality from config

Run '$0 help [COMMAND]' for more information on a specific command.
EOF
}

# Process command (main functionality)
command_process() {
    # Check for process-specific help
    if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
        show_process_help
        exit 0
    fi
    
    # Check for dry-run mode
    local dry_run=false
    local args=()
    
    # Parse arguments for dry-run flag
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    if [[ "$dry_run" == "true" ]]; then
        # Run comprehensive validation without actual processing
        if [[ ${#args[@]} -gt 0 ]]; then
            validate_processing_setup "${args[@]}"
        else
            validate_processing_setup
        fi
        exit 0
    else
        # Run the main processing function with remaining arguments
        if [[ ${#args[@]} -gt 0 ]]; then
            main "${args[@]}"
        else
            main
        fi
    fi
}

# Status command
command_status() {
    if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
        show_status_help
        exit 0
    fi
    
    echo "🔍 DJI Processor Status"
    echo "======================"
    
    # Check for running processes
    local running_jobs
    running_jobs=$(pgrep -f "avata2_dlog_optimized.sh" | wc -l)
    
    if [[ $running_jobs -gt 1 ]]; then
        log_info "📊 Processing jobs currently running: $((running_jobs - 1))"
        
        # Show running job details if possible
        if command -v ps >/dev/null 2>&1; then
            echo ""
            echo "Active processes:"
            ps aux | grep "avata2_dlog_optimized.sh" | grep -v grep | grep -v "command_status"
        fi
    else
        log_info "💤 No processing jobs currently running"
    fi
    
    # Show configuration status
    echo ""
    log_info "📋 Configuration Status:"
    if [[ -f "$CONFIG_FILE" ]]; then
        log_success "✅ Config file found: $CONFIG_FILE"
    elif [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        log_success "✅ Config file found: $DEFAULT_CONFIG_FILE"
    else
        log_warning "⚠️  No configuration file found"
        log_info "💡 Run './avata2_dlog_optimized.sh config --setup-wizard' to create one"
    fi
    
    # Check dependencies
    echo ""
    log_info "🔧 Dependencies:"
    if command -v ffmpeg >/dev/null 2>&1; then
        log_success "✅ FFmpeg found: $(ffmpeg -version 2>/dev/null | head -n1)"
    else
        log_error "❌ FFmpeg not found"
    fi
    
    if command -v ffprobe >/dev/null 2>&1; then
        log_success "✅ FFprobe found"
    else
        log_error "❌ FFprobe not found"
    fi
}

# Config command
command_config() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        -h|--help)
            show_config_help
            exit 0
            ;;
        --setup-wizard)
            interactive_config_wizard
            exit 0
            ;;
        --show)
            show_current_config
            ;;
        --validate)
            validate_current_config
            ;;
        *)
            log_error "Unknown config subcommand: $subcommand"
            echo ""
            show_config_help
            exit 1
            ;;
    esac
}

# Validate command
command_validate() {
    if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
        show_validate_help
        exit 0
    fi
    
    log_info "🔍 Validating DJI Processor Setup"
    echo "================================="
    
    local errors=0
    
    # Load configuration for validation
    apply_config
    
    # Validate source directory
    if [[ -d "$SOURCE_DIR" ]]; then
        log_success "✅ Source directory exists: $SOURCE_DIR"
    else
        log_error "❌ Source directory not found: $SOURCE_DIR"
        ((errors++))
    fi
    
    # Validate output directory (create if doesn't exist)
    if [[ -d "$FINAL_DIR" ]]; then
        log_success "✅ Output directory exists: $FINAL_DIR"
    else
        log_warning "⚠️  Output directory doesn't exist: $FINAL_DIR"
        log_info "💡 Will be created automatically during processing"
    fi
    
    # Validate LUT file
    if [[ -f "$LUT_FILE" ]]; then
        log_success "✅ LUT file found: $LUT_FILE"
    else
        log_error "❌ LUT file not found: $LUT_FILE"
        ((errors++))
    fi
    
    # Validate dependencies
    check_dependencies
    
    # Summary
    echo ""
    if [[ $errors -eq 0 ]]; then
        log_success "🎉 Validation complete - setup looks good!"
        exit 0
    else
        log_error "💥 Validation failed with $errors error(s)"
        log_info "💡 Fix the errors above and run validation again"
        exit 1
    fi
}

# Help command
command_help() {
    local topic="${1:-}"
    
    case "$topic" in
        process)
            show_process_help
            ;;
        status)
            show_status_help
            ;;
        config)
            show_config_help
            ;;
        validate)
            show_validate_help
            ;;
        "")
            show_general_help
            ;;
        completion)
            show_completion_help
            ;;
        *)
            log_error "No help available for: $topic"
            echo ""
            log_info "Available help topics: process, status, config, validate, completion"
            exit 1
            ;;
    esac
}

# Completion command
command_completion() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        -h|--help)
            show_completion_help
            exit 0
            ;;
        --install)
            install_bash_completion
            ;;
        --generate)
            generate_bash_completion
            ;;
        --show)
            generate_bash_completion
            ;;
        "")
            # Default action: show completion script
            generate_bash_completion
            ;;
        *)
            log_error "Unknown completion subcommand: $subcommand"
            echo ""
            show_completion_help
            exit 1
            ;;
    esac
}

# Individual help functions
show_process_help() {
    cat << EOF
Usage: $0 process [OPTIONS] [SOURCE_DIRECTORY] [OUTPUT_DIRECTORY] [LUT_FILE]

Process DJI D-Log videos to Rec.709 color space.

OPTIONS:
  --dry-run          Validate configuration and setup without processing any files
  -h, --help         Show this help message

ARGUMENTS:
  SOURCE_DIRECTORY   Directory containing D-Log video files (optional if configured)
  OUTPUT_DIRECTORY   Directory for processed videos (optional if configured)
  LUT_FILE          Path to LUT file (.cube format) (optional if configured)

EXAMPLES:
  $0 process                                 # Use configuration file settings
  $0 process --dry-run                       # Validate setup without processing
  $0 process /path/to/source                 # Override source directory
  $0 process /source /output /lut.cube       # Override all paths
  $0 process --dry-run /path/to/source       # Validate with custom source
  QUALITY_PRESET=high $0 process             # Override quality setting

VALIDATION:
  The --dry-run option performs comprehensive validation including:
  - Configuration file syntax and values
  - Source directory existence and permissions
  - Output directory creation and write access
  - LUT file validity and format checking
  - Disk space availability
  - Dependencies and encoder availability
  - Processing time and size estimation

For more options, see the main configuration file or environment variables.
EOF
}

show_status_help() {
    cat << EOF
Usage: $0 status [OPTIONS]

Show current processing status and system information.

OPTIONS:
  -h, --help     Show this help message

EXAMPLES:
  $0 status      # Show current status
EOF
}

show_config_help() {
    cat << EOF
Usage: $0 config [SUBCOMMAND] [OPTIONS]

Manage configuration settings.

SUBCOMMANDS:
  --setup-wizard    Interactive configuration setup wizard
  --show           Show current configuration
  --validate       Validate current configuration
  -h, --help       Show this help message

EXAMPLES:
  $0 config --setup-wizard    # Create new configuration interactively
  $0 config --show           # Display current settings
  $0 config --validate       # Check configuration validity

SETUP WIZARD:
  The interactive wizard guides you through:
  - Source and output directory selection
  - LUT file configuration
  - Quality and performance settings
  - Workflow options (backup, organization)
  - Configuration file location choice
  - Optional validation testing

  Perfect for first-time setup or creating new configurations.
EOF
}

show_validate_help() {
    cat << EOF
Usage: $0 validate [OPTIONS]

Validate the current setup and configuration.

Checks:
  - Source directory exists
  - Output directory accessibility
  - LUT file exists
  - Dependencies (ffmpeg, ffprobe)
  - Configuration file validity

OPTIONS:
  -h, --help     Show this help message

EXAMPLES:
  $0 validate    # Run full validation
EOF
}

show_completion_help() {
    cat << EOF
Usage: $0 completion [SUBCOMMAND] [OPTIONS]

Generate and manage bash completion for the DJI processor.

SUBCOMMANDS:
  --generate     Generate completion script (default)
  --show         Show completion script (same as --generate)
  --install      Install completion script to system
  -h, --help     Show this help message

EXAMPLES:
  $0 completion                    # Show completion script
  $0 completion --generate         # Generate completion script  
  $0 completion --install          # Install system-wide completion
  $0 completion > /usr/local/etc/bash_completion.d/dji-processor

INSTALLATION:
  Option 1 - Automatic installation:
    $0 completion --install

  Option 2 - Manual installation:
    $0 completion > ~/.local/share/bash-completion/completions/dji-processor
    source ~/.local/share/bash-completion/completions/dji-processor

  Option 3 - Session-only:
    eval "\$($0 completion)"

FEATURES:
  - Command completion (process, status, config, validate, help)
  - Option completion (--dry-run, --setup-wizard, etc.)
  - File path completion for directories and LUT files
  - Dynamic preset completion (high, medium, low)
  - Context-aware suggestions
EOF
}

# Helper functions for config command
show_current_config() {
    log_info "📋 Current Configuration"
    echo "========================"
    
    # Load configuration
    apply_config
    
    echo "Source directory: $SOURCE_DIR"
    echo "Output directory: $FINAL_DIR"
    echo "LUT file: $LUT_FILE"
    echo "Quality preset: $QUALITY_PRESET"
    echo "Parallel jobs: $PARALLEL_JOBS"
    echo "Auto backup: $AUTO_BACKUP"
    echo "Skip existing: $SKIP_EXISTING"
    echo "Organize by date: $ORGANIZE_BY_DATE"
    echo "Preserve metadata: $PRESERVE_METADATA"
    echo "Verbose logging: $VERBOSE_LOGGING"
}

validate_current_config() {
    log_info "🔍 Validating Configuration"
    echo "============================"
    
    apply_config
    
    local config_file=""
    if [[ -f "$CONFIG_FILE" ]]; then
        config_file="$CONFIG_FILE"
    elif [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        config_file="$DEFAULT_CONFIG_FILE"
    fi
    
    if [[ -n "$config_file" ]]; then
        log_success "✅ Configuration file: $config_file"
        
        # Basic YAML syntax check
        if command -v python3 >/dev/null 2>&1; then
            if python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
                log_success "✅ Configuration syntax is valid"
            else
                log_error "❌ Configuration syntax error"
            fi
        else
            log_info "💡 Install python3 with PyYAML for advanced config validation"
        fi
    else
        log_warning "⚠️  No configuration file found - using defaults"
    fi
}

# Interactive Configuration Wizard
interactive_config_wizard() {
    echo ""
    log_info "🧙 DJI Video Processor Configuration Wizard"
    echo "============================================="
    echo ""
    log_info "This wizard will help you create an optimized configuration file."
    echo ""
    
    # Initialize wizard variables
    local wizard_source_dir=""
    local wizard_output_dir=""
    local wizard_lut_file=""
    local wizard_quality="medium"
    local wizard_parallel="auto"
    local wizard_auto_backup="false"
    local wizard_organize_date="false"
    local wizard_notifications="true"
    local wizard_config_file=""
    
    # Helper function for user input with default
    prompt_with_default() {
        local prompt="$1"
        local default="$2"
        local validation_func="${3:-}"
        local user_input=""
        
        while true; do
            if [[ -n "$default" ]]; then
                echo -n "$prompt [$default]: "
            else
                echo -n "$prompt: "
            fi
            read -r user_input
            
            # Use default if input is empty
            if [[ -z "$user_input" ]] && [[ -n "$default" ]]; then
                user_input="$default"
            fi
            
            # Validate input if validation function provided
            if [[ -n "$validation_func" ]]; then
                if $validation_func "$user_input"; then
                    echo "$user_input"
                    return 0
                else
                    log_error "Invalid input. Please try again."
                    continue
                fi
            else
                echo "$user_input"
                return 0
            fi
        done
    }
    
    # Validation functions
    validate_directory() {
        local dir="$1"
        if [[ -z "$dir" ]]; then
            echo "Directory path cannot be empty"
            return 1
        fi
        if [[ ! "$dir" =~ ^(/|~/|\\./) ]]; then
            echo "Please provide a full path (starting with /, ~/, or ./)"
            return 1
        fi
        return 0
    }
    
    validate_file() {
        local file="$1"
        if [[ -z "$file" ]]; then
            echo "File path cannot be empty"
            return 1
        fi
        if [[ ! "$file" =~ ^(/|~/|\\./) ]]; then
            echo "Please provide a full path (starting with /, ~/, or ./)"
            return 1
        fi
        return 0
    }
    
    validate_quality() {
        local quality="$1"
        case "$quality" in
            high|medium|low) return 0 ;;
            *) echo "Quality must be 'high', 'medium', or 'low'"; return 1 ;;
        esac
    }
    
    validate_parallel() {
        local parallel="$1"
        if [[ "$parallel" == "auto" ]]; then
            return 0
        elif [[ "$parallel" =~ ^[0-9]+$ ]] && [[ $parallel -ge 1 ]] && [[ $parallel -le 16 ]]; then
            return 0
        else
            echo "Parallel jobs must be 'auto' or a number between 1-16"
            return 1
        fi
    }
    
    validate_yes_no() {
        local answer="$1"
        case "${answer,,}" in
            y|yes|true) echo "true"; return 0 ;;
            n|no|false) echo "false"; return 0 ;;
            *) echo "Please answer 'y' for yes or 'n' for no"; return 1 ;;
        esac
    }
    
    # Step 1: Source Directory
    echo "📁 Step 1/8: Source Directory"
    echo "Where are your DJI D-Log video files stored?"
    echo "This directory should contain your .mp4 or .mov files from your drone."
    echo ""
    
    local default_source="$HOME/Movies/DJI/source"
    wizard_source_dir=$(prompt_with_default "Source directory" "$default_source" "validate_directory")
    
    # Check if source directory exists and offer to create it
    if [[ ! -d "$wizard_source_dir" ]]; then
        echo ""
        log_warning "Directory doesn't exist: $wizard_source_dir"
        local create_dir
        create_dir=$(prompt_with_default "Create this directory? (y/n)" "y" "validate_yes_no")
        if [[ "$create_dir" == "true" ]]; then
            if mkdir -p "$wizard_source_dir" 2>/dev/null; then
                log_success "✅ Created directory: $wizard_source_dir"
            else
                log_error "❌ Failed to create directory. Please check permissions."
                echo "You may need to create this directory manually later."
            fi
        fi
    fi
    
    echo ""
    
    # Step 2: Output Directory
    echo "📁 Step 2/8: Output Directory"
    echo "Where should processed videos be saved?"
    echo ""
    
    local default_output="$HOME/Movies/DJI/final"
    wizard_output_dir=$(prompt_with_default "Output directory" "$default_output" "validate_directory")
    
    # Check if output directory exists and offer to create it
    if [[ ! -d "$wizard_output_dir" ]]; then
        echo ""
        log_warning "Directory doesn't exist: $wizard_output_dir"
        local create_dir
        create_dir=$(prompt_with_default "Create this directory? (y/n)" "y" "validate_yes_no")
        if [[ "$create_dir" == "true" ]]; then
            if mkdir -p "$wizard_output_dir" 2>/dev/null; then
                log_success "✅ Created directory: $wizard_output_dir"
            else
                log_error "❌ Failed to create directory. Please check permissions."
                echo "You may need to create this directory manually later."
            fi
        fi
    fi
    
    echo ""
    
    # Step 3: LUT File
    echo "🎨 Step 3/8: LUT File"
    echo "Path to your DJI D-Log LUT file (.cube format)."
    echo "This file converts your D-Log footage to standard Rec.709 color space."
    echo ""
    
    local default_lut="$HOME/Movies/DJI/Avata2.cube"
    wizard_lut_file=$(prompt_with_default "LUT file path" "$default_lut" "validate_file")
    
    # Check if LUT file exists
    if [[ ! -f "$wizard_lut_file" ]]; then
        echo ""
        log_warning "LUT file not found: $wizard_lut_file"
        echo "💡 You'll need to obtain a LUT file for your specific DJI drone model."
        echo "💡 Common locations: DJI Assistant software, online DJI resources"
    else
        log_success "✅ LUT file found: $wizard_lut_file"
    fi
    
    echo ""
    
    # Step 4: Quality Preset
    echo "⚙️ Step 4/8: Quality Preset"
    echo "Choose the video quality preset:"
    echo "  high   = 15Mbps (best quality, larger files, good for archival)"
    echo "  medium = 10Mbps (balanced quality/size, good for general use)"
    echo "  low    = 6Mbps  (smaller files, good for web sharing)"
    echo ""
    
    wizard_quality=$(prompt_with_default "Quality preset (high/medium/low)" "medium" "validate_quality")
    echo ""
    
    # Step 5: Parallel Processing
    echo "🚀 Step 5/8: Parallel Processing"
    local detected_cores
    detected_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
    echo "Your system has $detected_cores CPU cores."
    echo "Parallel processing can speed up batch operations."
    echo "  auto = automatically detect optimal number of jobs"
    echo "  1-16 = specific number of simultaneous processing jobs"
    echo ""
    
    wizard_parallel=$(prompt_with_default "Parallel jobs (auto/1-16)" "auto" "validate_parallel")
    echo ""
    
    # Step 6: Auto Backup
    echo "💾 Step 6/8: Auto Backup"
    echo "Automatically backup original files before processing?"
    echo "This creates a safety copy of your original footage."
    echo ""
    
    local backup_answer
    backup_answer=$(prompt_with_default "Enable auto backup? (y/n)" "n" "validate_yes_no")
    wizard_auto_backup="$backup_answer"
    echo ""
    
    # Step 7: File Organization
    echo "📅 Step 7/8: File Organization"
    echo "Organize processed files by date in subdirectories?"
    echo "This creates folders like '2025-01-15' for better organization."
    echo ""
    
    local organize_answer
    organize_answer=$(prompt_with_default "Organize by date? (y/n)" "n" "validate_yes_no")
    wizard_organize_date="$organize_answer"
    echo ""
    
    # Step 8: Notifications
    echo "🔔 Step 8/8: Notifications"
    echo "Enable macOS notifications when processing completes?"
    echo ""
    
    local notification_answer
    notification_answer=$(prompt_with_default "Enable notifications? (y/n)" "y" "validate_yes_no")
    wizard_notifications="$notification_answer"
    echo ""
    
    # Configuration Summary
    echo "📋 Configuration Summary"
    echo "========================"
    echo "Source directory: $wizard_source_dir"
    echo "Output directory: $wizard_output_dir"
    echo "LUT file: $wizard_lut_file"
    echo "Quality preset: $wizard_quality"
    echo "Parallel jobs: $wizard_parallel"
    echo "Auto backup: $wizard_auto_backup"
    echo "Organize by date: $wizard_organize_date"
    echo "Notifications: $wizard_notifications"
    echo ""
    
    # Confirm configuration
    local confirm_answer
    confirm_answer=$(prompt_with_default "Save this configuration? (y/n)" "y" "validate_yes_no")
    
    if [[ "$confirm_answer" == "false" ]]; then
        log_info "Configuration wizard cancelled. No changes made."
        return 0
    fi
    
    # Choose configuration file location
    echo ""
    echo "💾 Configuration File Location"
    echo "Choose where to save your configuration:"
    echo "  1. ~/.dji-processor/config.yml (user-global, recommended)"
    echo "  2. ./dji-config.yml (project-specific)"
    echo "  3. Custom location"
    echo ""
    
    local location_choice
    location_choice=$(prompt_with_default "Choose location (1/2/3)" "1")
    
    case "$location_choice" in
        1)
            wizard_config_file="$HOME/.dji-processor/config.yml"
            mkdir -p "$HOME/.dji-processor"
            ;;
        2)
            wizard_config_file="./dji-config.yml"
            ;;
        3)
            wizard_config_file=$(prompt_with_default "Custom config file path" "$HOME/dji-config.yml" "validate_file")
            local config_dir
            config_dir=$(dirname "$wizard_config_file")
            mkdir -p "$config_dir" 2>/dev/null
            ;;
        *)
            log_warning "Invalid choice, using default location"
            wizard_config_file="$HOME/.dji-processor/config.yml"
            mkdir -p "$HOME/.dji-processor"
            ;;
    esac
    
    # Generate configuration file
    echo ""
    log_info "💾 Generating configuration file..."
    
    cat > "$wizard_config_file" << EOF
# DJI Avata 2 D-Log Video Processor Configuration
# Generated by Configuration Wizard on $(date)

# === PATHS ===
source_directory: "$wizard_source_dir"
output_directory: "$wizard_output_dir"
lut_file: "$wizard_lut_file"

# === PROCESSING SETTINGS ===
quality_preset: "$wizard_quality"
parallel_jobs: "$wizard_parallel"

# === WORKFLOW OPTIONS ===
auto_backup: $wizard_auto_backup
skip_existing: true
organize_by_date: $wizard_organize_date
preserve_timestamps: true
preserve_metadata: true

# === NOTIFICATIONS ===
macos_notifications: $wizard_notifications
completion_sound: $wizard_notifications

# === PERFORMANCE ===
max_cpu_usage: 90
thermal_protection: true

# === FILE HANDLING ===
file_extensions:
  - "mp4"
  - "MP4"
  - "mov"
  - "MOV"

min_file_size: 10
max_file_size: 0

# Additional settings can be added manually
# See examples/ directory for more configuration options
EOF
    
    if [[ $? -eq 0 ]]; then
        log_success "✅ Configuration saved to: $wizard_config_file"
        echo ""
        
        # Offer to test configuration
        local test_answer
        test_answer=$(prompt_with_default "Test configuration with dry-run? (y/n)" "y" "validate_yes_no")
        
        if [[ "$test_answer" == "true" ]]; then
            echo ""
            log_info "🔍 Testing configuration..."
            echo ""
            
            # Set the config file and run dry-run validation
            CONFIG_FILE="$wizard_config_file" validate_processing_setup
        else
            echo ""
            log_info "🎉 Configuration wizard completed successfully!"
            echo ""
            log_info "💡 Next steps:"
            echo "  1. Copy your DJI D-Log video files to: $wizard_source_dir"
            echo "  2. Ensure your LUT file is available at: $wizard_lut_file"
            echo "  3. Run: ./avata2_dlog_optimized.sh process"
            echo "  4. Or test first: ./avata2_dlog_optimized.sh process --dry-run"
        fi
    else
        log_error "❌ Failed to save configuration file"
        log_info "💡 Please check file permissions and try again"
        return 1
    fi
}

# Generate bash completion script
generate_bash_completion() {
    local script_name
    script_name=$(basename "$0")
    
    cat << 'EOF'
#!/bin/bash
# Bash completion for DJI Avata 2 D-Log Processor
# Generated automatically - do not edit manually

_dji_processor_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main commands
    local commands="process status config validate help completion"
    
    # Global options
    local global_opts="-h --help"
    
    # Process command options
    local process_opts="--dry-run -h --help"
    
    # Config command options  
    local config_opts="--setup-wizard --show --validate -h --help"
    
    # Quality presets
    local quality_presets="high medium low"
    
    # Get current command (first non-option argument)
    local command=""
    local i=1
    while [[ $i -lt ${#COMP_WORDS[@]} ]]; do
        local word="${COMP_WORDS[$i]}"
        if [[ ! "$word" =~ ^- ]] && [[ "$word" != "$cur" ]]; then
            command="$word"
            break
        fi
        ((i++))
    done
    
    # Handle completion based on context
    case "$prev" in
        # File/directory completions
        --lut-file|lut_file)
            COMPREPLY=($(compgen -f -X '!*.cube' -- "$cur"))
            return 0
            ;;
        --source|--output|source_directory|output_directory)
            COMPREPLY=($(compgen -d -- "$cur"))
            return 0
            ;;
        --quality|quality_preset|QUALITY_PRESET)
            COMPREPLY=($(compgen -W "$quality_presets" -- "$cur"))
            return 0
            ;;
        --parallel|parallel_jobs|PARALLEL_JOBS)
            COMPREPLY=($(compgen -W "auto 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16" -- "$cur"))
            return 0
            ;;
    esac
    
    # Command-specific completion
    case "$command" in
        process)
            case "$cur" in
                -*)
                    COMPREPLY=($(compgen -W "$process_opts" -- "$cur"))
                    ;;
                *)
                    # Complete with directories for positional arguments
                    COMPREPLY=($(compgen -d -- "$cur"))
                    ;;
            esac
            return 0
            ;;
        config)
            case "$cur" in
                -*)
                    COMPREPLY=($(compgen -W "$config_opts" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$config_opts" -- "$cur"))
                    ;;
            esac
            return 0
            ;;
        status|validate)
            case "$cur" in
                -*)
                    COMPREPLY=($(compgen -W "-h --help" -- "$cur"))
                    ;;
            esac
            return 0
            ;;
        help)
            case "$cur" in
                *)
                    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
                    ;;
            esac
            return 0
            ;;
        completion)
            case "$cur" in
                -*)
                    COMPREPLY=($(compgen -W "--generate --show --install -h --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "--generate --show --install" -- "$cur"))
                    ;;
            esac
            return 0
            ;;
        "")
            # No command yet - complete with commands or global options
            case "$cur" in
                -*)
                    COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
                    ;;
                *)
                    # Check if it might be a directory (legacy mode)
                    if [[ -d "$cur" ]] || [[ "$cur" =~ ^[./~] ]]; then
                        COMPREPLY=($(compgen -d -- "$cur"))
                    else
                        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
                    fi
                    ;;
            esac
            return 0
            ;;
    esac
    
    # Default completion
    case "$cur" in
        -*)
            COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
            ;;
        *)
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            ;;
    esac
}

# Register completion function
EOF
    
    echo "complete -F _dji_processor_completion $script_name"
    echo ""
    echo "# Additional dynamic completions for environment variables"
    echo "complete -W 'high medium low' -v QUALITY_PRESET"
    echo "complete -W 'auto 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16' -v PARALLEL_JOBS"
}

# Install bash completion
install_bash_completion() {
    log_info "🔧 Installing Bash Completion"
    echo "================================"
    
    local script_name
    script_name=$(basename "$0")
    local completion_file=""
    local installed=false
    
    # Try different completion directories
    local completion_dirs=(
        "/usr/local/etc/bash_completion.d"
        "/opt/homebrew/etc/bash_completion.d" 
        "$HOME/.local/share/bash-completion/completions"
        "$HOME/.bash_completion.d"
    )
    
    for dir in "${completion_dirs[@]}"; do
        if [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null; then
            completion_file="$dir/dji-processor"
            if generate_bash_completion > "$completion_file" 2>/dev/null; then
                chmod +x "$completion_file" 2>/dev/null
                log_success "✅ Completion installed to: $completion_file"
                installed=true
                break
            else
                log_warning "⚠️  Cannot write to: $dir"
            fi
        fi
    done
    
    if [[ "$installed" == "false" ]]; then
        log_error "❌ Could not install completion automatically"
        echo ""
        log_info "💡 Manual installation options:"
        echo ""
        echo "1. Save completion script:"
        echo "   $0 completion > ~/.local/share/bash-completion/completions/dji-processor"
        echo ""
        echo "2. Source in current session:"
        echo "   eval \"\$($0 completion)\""
        echo ""
        echo "3. Add to .bashrc/.bash_profile:"
        echo "   echo 'eval \"\$($PWD/$script_name completion)\"' >> ~/.bashrc"
        return 1
    fi
    
    echo ""
    log_info "🔄 Enabling Completion"
    
    # Try to source the completion immediately
    if [[ -f "$completion_file" ]]; then
        if source "$completion_file" 2>/dev/null; then
            log_success "✅ Completion enabled for current session"
        else
            log_warning "⚠️  Completion installed but not loaded in current session"
        fi
    fi
    
    echo ""
    log_info "💡 Next Steps:"
    echo "1. Restart your terminal or run: source $completion_file"
    echo "2. Test completion: type '$script_name <TAB><TAB>'"
    echo "3. Try: '$script_name config --<TAB>' or '$script_name help <TAB>'"
    
    # Test if completion is working
    echo ""
    log_info "🧪 Testing Completion"
    echo "Try these examples:"
    echo "  $script_name <TAB><TAB>     # Show all commands"
    echo "  $script_name config --<TAB>  # Show config options"
    echo "  $script_name help <TAB>     # Show help topics"
    echo "  QUALITY_PRESET=<TAB>        # Show quality presets"
}

# Parse and route commands
parse_command "$@"