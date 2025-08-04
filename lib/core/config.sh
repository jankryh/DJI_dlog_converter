#!/bin/bash
# DJI Processor - Configuration Module
# Handles YAML configuration file parsing and environment management

# Prevent multiple sourcing
[[ "${_DJI_CONFIG_LOADED:-}" == "true" ]] && return 0
readonly _DJI_CONFIG_LOADED=true

# Source dependencies
[[ "${_DJI_LOGGING_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
[[ "${_DJI_UTILS_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Configuration file paths
CONFIG_FILE="${CONFIG_FILE:-./dji-config.yml}"
DEFAULT_CONFIG_FILE="$HOME/.dji-processor/config.yml"

# Initialize default configuration values
init_default_config() {
    # Core processing paths - standard project structure
    SOURCE_DIR="${SOURCE_DIR:-./input}"
    FINAL_DIR="${FINAL_DIR:-./output}"
    LUT_FILE="${LUT_FILE:-./luts/Avata2.cube}"
    
    # Processing settings
    BAR_LENGTH="${BAR_LENGTH:-50}"
    QUALITY_PRESET="${QUALITY_PRESET:-high}"
    PARALLEL_JOBS="${PARALLEL_JOBS:-auto}"
    
    # Backup and organization
    AUTO_BACKUP="${AUTO_BACKUP:-false}"
    BACKUP_DIR="${BACKUP_DIR:-./backup}"
    SKIP_EXISTING="${SKIP_EXISTING:-true}"
    ORGANIZE_BY_DATE="${ORGANIZE_BY_DATE:-false}"
    DATE_FORMAT="${DATE_FORMAT:-%Y-%m-%d}"
    
    # Advanced settings
    FORCE_ENCODER="${FORCE_ENCODER:-auto}"
    CUSTOM_FFMPEG_ARGS="${CUSTOM_FFMPEG_ARGS:-}"
    
    # Logging and monitoring
    VERBOSE_LOGGING="${VERBOSE_LOGGING:-false}"
    LOG_FILE="${LOG_FILE:-}"
    KEEP_JOB_LOGS="${KEEP_JOB_LOGS:-false}"
    
    # System integration
    MACOS_NOTIFICATIONS="${MACOS_NOTIFICATIONS:-true}"
    COMPLETION_SOUND="${COMPLETION_SOUND:-true}"
    
    # Performance and protection
    MAX_CPU_USAGE="${MAX_CPU_USAGE:-90}"
    THERMAL_PROTECTION="${THERMAL_PROTECTION:-true}"
    
    # File filtering
    MIN_FILE_SIZE="${MIN_FILE_SIZE:-10}"
    MAX_FILE_SIZE="${MAX_FILE_SIZE:-0}"
    
    # Metadata handling
    PRESERVE_TIMESTAMPS="${PRESERVE_TIMESTAMPS:-true}"
    PRESERVE_METADATA="${PRESERVE_METADATA:-true}"
    ADD_PROCESSING_METADATA="${ADD_PROCESSING_METADATA:-false}"
    
    # Export configuration for other modules
    export SOURCE_DIR FINAL_DIR LUT_FILE BAR_LENGTH QUALITY_PRESET PARALLEL_JOBS
    export AUTO_BACKUP BACKUP_DIR SKIP_EXISTING ORGANIZE_BY_DATE DATE_FORMAT
    export FORCE_ENCODER CUSTOM_FFMPEG_ARGS VERBOSE_LOGGING LOG_FILE KEEP_JOB_LOGS
    export MACOS_NOTIFICATIONS COMPLETION_SOUND MAX_CPU_USAGE THERMAL_PROTECTION
    export MIN_FILE_SIZE MAX_FILE_SIZE PRESERVE_TIMESTAMPS PRESERVE_METADATA ADD_PROCESSING_METADATA
}

# Parse configuration value from YAML-like format
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

# Parse boolean configuration value
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

# Load configuration from file
load_config_file() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # Validate config file is readable
    if [[ ! -r "$config_file" ]]; then
        log_error "Cannot read configuration file: $config_file"
        return 1
    fi
    
    # Basic YAML syntax validation (if PyYAML is available)
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml" 2>/dev/null; then
            if ! python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
                log_error "YAML syntax error in configuration file: $config_file"
                return 1
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

# Apply configuration with command line and environment overrides
apply_config() {
    # Initialize defaults first
    init_default_config
    
    # Try to load configuration file
    if [[ -f "$CONFIG_FILE" ]]; then
        load_config_file "$CONFIG_FILE"
    elif [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        load_config_file "$DEFAULT_CONFIG_FILE"
    fi
    
    # Handle parallel jobs setting with validation
    if [[ "$PARALLEL_JOBS" == "auto" || "$PARALLEL_JOBS" == "0" ]]; then
        PARALLEL_JOBS=$(get_cpu_cores)
    elif ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ $PARALLEL_JOBS -lt 1 ]] || [[ $PARALLEL_JOBS -gt 32 ]]; then
        log_error "Invalid parallel_jobs value: $PARALLEL_JOBS (must be 1-32 or 'auto')"
        return 1
    fi
    
    # Apply command line overrides
    [[ -n "${1:-}" ]] && SOURCE_DIR="$1"
    [[ -n "${2:-}" ]] && FINAL_DIR="$2"
    [[ -n "${3:-}" ]] && LUT_FILE="$3"
    
    # Re-validate after environment variable overrides
    if [[ "$PARALLEL_JOBS" != "auto" && "$PARALLEL_JOBS" != "0" ]]; then
        if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ $PARALLEL_JOBS -lt 1 ]] || [[ $PARALLEL_JOBS -gt 32 ]]; then
            log_error "Invalid PARALLEL_JOBS environment variable: $PARALLEL_JOBS (must be 1-32 or 'auto')"
            return 1
        fi
    fi
    
    case "$QUALITY_PRESET" in
        high|medium|low) ;;
        *) log_error "Invalid QUALITY_PRESET value: $QUALITY_PRESET (must be 'high', 'medium', or 'low')"; return 1 ;;
    esac
    
    # Re-export all configuration
    export SOURCE_DIR FINAL_DIR LUT_FILE BAR_LENGTH QUALITY_PRESET PARALLEL_JOBS
    export AUTO_BACKUP BACKUP_DIR SKIP_EXISTING ORGANIZE_BY_DATE DATE_FORMAT
    export FORCE_ENCODER CUSTOM_FFMPEG_ARGS VERBOSE_LOGGING LOG_FILE KEEP_JOB_LOGS
    export MACOS_NOTIFICATIONS COMPLETION_SOUND MAX_CPU_USAGE THERMAL_PROTECTION
    export MIN_FILE_SIZE MAX_FILE_SIZE PRESERVE_TIMESTAMPS PRESERVE_METADATA ADD_PROCESSING_METADATA
}

# Get configuration value by key
get_config_value() {
    local key="$1"
    
    case "$key" in
        source_directory) echo "$SOURCE_DIR" ;;
        output_directory) echo "$FINAL_DIR" ;;
        lut_file) echo "$LUT_FILE" ;;
        quality_preset) echo "$QUALITY_PRESET" ;;
        parallel_jobs) echo "$PARALLEL_JOBS" ;;
        auto_backup) echo "$AUTO_BACKUP" ;;
        backup_directory) echo "$BACKUP_DIR" ;;
        skip_existing) echo "$SKIP_EXISTING" ;;
        organize_by_date) echo "$ORGANIZE_BY_DATE" ;;
        date_format) echo "$DATE_FORMAT" ;;
        force_encoder) echo "$FORCE_ENCODER" ;;
        custom_ffmpeg_args) echo "$CUSTOM_FFMPEG_ARGS" ;;
        verbose_logging) echo "$VERBOSE_LOGGING" ;;
        log_file) echo "$LOG_FILE" ;;
        keep_job_logs) echo "$KEEP_JOB_LOGS" ;;
        macos_notifications) echo "$MACOS_NOTIFICATIONS" ;;
        completion_sound) echo "$COMPLETION_SOUND" ;;
        max_cpu_usage) echo "$MAX_CPU_USAGE" ;;
        thermal_protection) echo "$THERMAL_PROTECTION" ;;
        min_file_size) echo "$MIN_FILE_SIZE" ;;
        max_file_size) echo "$MAX_FILE_SIZE" ;;
        preserve_timestamps) echo "$PRESERVE_TIMESTAMPS" ;;
        preserve_metadata) echo "$PRESERVE_METADATA" ;;
        add_processing_metadata) echo "$ADD_PROCESSING_METADATA" ;;
        *) echo "" ;;
    esac
}

# Create default configuration file
create_default_config() {
    local config_path="${1:-$CONFIG_FILE}"
    local config_dir
    config_dir="$(dirname "$config_path")"
    
    mkdir -p "$config_dir"
    
    cat > "$config_path" << 'EOF'
# DJI Video Processor Configuration
# Auto-generated configuration file

# Core Settings
source_directory: "./input"
output_directory: "./output"
lut_file: "./luts/Avata2.cube"

# Processing Settings
quality_preset: "high"           # high, medium, low
parallel_jobs: "auto"            # auto, 1-32, or specific number

# Backup & Organization
auto_backup: false
backup_directory: "./backup"
skip_existing: true
organize_by_date: false
date_format: "%Y-%m-%d"

# Advanced Options
force_encoder: "auto"            # auto, h264_videotoolbox, libx264
custom_ffmpeg_args: ""

# Logging & Monitoring
verbose_logging: false
log_file: ""                     # leave empty for no file logging
keep_job_logs: false

# System Integration (macOS)
macos_notifications: true
completion_sound: true

# Performance & Protection
max_cpu_usage: 90                # percentage
thermal_protection: true

# File Filtering
min_file_size: 10                # MB
max_file_size: 0                 # GB, 0 = no limit

# Metadata Handling
preserve_timestamps: true
preserve_metadata: true
add_processing_metadata: false
EOF
    
    log_info "Created default configuration: $config_path"
}

# Validate configuration
validate_config() {
    local errors=0
    
    # Validate paths
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_warning "Source directory does not exist: $SOURCE_DIR"
        log_info "💡 Create it with: mkdir -p \"$SOURCE_DIR\""
        # Don't count as error for validation, just warning
    fi
    
    if [[ ! -f "$LUT_FILE" ]]; then
        log_error "LUT file does not exist: $LUT_FILE"
        ((errors++))
    fi
    
    # Validate quality preset
    if ! validate_quality "$QUALITY_PRESET"; then
        log_error "Invalid quality preset: $QUALITY_PRESET"
        ((errors++))
    fi
    
    # Validate parallel jobs
    if ! validate_parallel "$PARALLEL_JOBS"; then
        log_error "Invalid parallel jobs setting: $PARALLEL_JOBS"
        ((errors++))
    fi
    
    return $errors
}

# Export functions for use in other modules
export -f init_default_config parse_config_value parse_config_bool
export -f load_config_file apply_config get_config_value
export -f create_default_config validate_config