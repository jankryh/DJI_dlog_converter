#!/bin/bash
# DJI Processor - Logging Module
# Provides structured logging with color support and error handling

# Prevent multiple sourcing
[[ "${_DJI_LOGGING_LOADED:-}" == "true" ]] && return 0
readonly _DJI_LOGGING_LOADED=true

# Color definitions for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global logging configuration
DJI_LOG_LEVEL="${DJI_LOG_LEVEL:-INFO}"
DJI_LOG_FILE="${DJI_LOG_FILE:-}"
DJI_LOG_TIMESTAMPS="${DJI_LOG_TIMESTAMPS:-false}"

# Initialize logging system
init_logging() {
    local log_file="${1:-}"
    local log_level="${2:-INFO}"
    local timestamps="${3:-false}"
    
    DJI_LOG_FILE="$log_file"
    DJI_LOG_LEVEL="$log_level"
    DJI_LOG_TIMESTAMPS="$timestamps"
    
    # Create log file if specified
    if [[ -n "$DJI_LOG_FILE" ]]; then
        mkdir -p "$(dirname "$DJI_LOG_FILE")"
        touch "$DJI_LOG_FILE" || {
            log_warning "Cannot create log file: $DJI_LOG_FILE"
            DJI_LOG_FILE=""
        }
    fi
}

# Get timestamp for logging
_get_timestamp() {
    if [[ "$DJI_LOG_TIMESTAMPS" == "true" ]]; then
        date '+%Y-%m-%d %H:%M:%S'
    fi
}

# Core logging function
_log() {
    local level="$1"
    local color="$2"
    local icon="$3"
    local message="$4"
    local stderr="${5:-false}"
    
    local timestamp
    timestamp="$(_get_timestamp)"
    local prefix=""
    [[ -n "$timestamp" ]] && prefix="[$timestamp] "
    
    local formatted_message="${color}${icon} ${message}${NC}"
    
    # Output to console
    if [[ "$stderr" == "true" ]]; then
        echo -e "${prefix}${formatted_message}" >&2
    else
        echo -e "${prefix}${formatted_message}"
    fi
    
    # Output to log file if configured
    if [[ -n "$DJI_LOG_FILE" ]]; then
        echo "${prefix}[$level] $message" >> "$DJI_LOG_FILE"
    fi
}

# Public logging functions
log_debug() {
    [[ "$DJI_LOG_LEVEL" =~ ^(DEBUG)$ ]] || return 0
    _log "DEBUG" "$BLUE" "🔍" "$1"
}

log_info() {
    [[ "$DJI_LOG_LEVEL" =~ ^(DEBUG|INFO)$ ]] || return 0
    _log "INFO" "$BLUE" "ℹ️ " "$1"
}

log_success() {
    [[ "$DJI_LOG_LEVEL" =~ ^(DEBUG|INFO|SUCCESS)$ ]] || return 0
    _log "SUCCESS" "$GREEN" "✅" "$1"
}

log_warning() {
    [[ "$DJI_LOG_LEVEL" =~ ^(DEBUG|INFO|SUCCESS|WARN)$ ]] || return 0
    _log "WARN" "$YELLOW" "⚠️ " "$1"
}

log_error() {
    _log "ERROR" "$RED" "❌" "$1" true
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
            log_info "💡 Run './dji-processor config --validate' to check your configuration"
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

# Progress logging functions
log_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"
    local percentage=$((current * 100 / total))
    
    printf "\r${BLUE}⏳ $message: $current/$total (${percentage}%%)${NC}"
}

log_progress_done() {
    printf "\n"
}

# Cleanup logging resources
cleanup_logging() {
    # Any cleanup needed for logging system
    log_debug "Logging system cleanup completed"
}

# Verbose logging function
log_verbose() {
    [[ "${VERBOSE_LOGGING:-false}" == "true" ]] || return 0
    _log "VERBOSE" "$CYAN" "🔍" "$1"
}

# Progress display function
show_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    
    local percentage=$((current * 100 / total))
    local bar_length=20
    local filled=$((current * bar_length / total))
    local bar=""
    
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=filled; i<bar_length; i++)); do
        bar+="░"
    done
    
    printf "\r%s [%s] %d/%d (%d%%)" "$message" "$bar" "$current" "$total" "$percentage"
    
    if [[ $current -eq $total ]]; then
        echo ""  # New line when complete
    fi
}

# Export functions for use in other modules
export -f log_debug log_info log_success log_warning log_error log_verbose show_progress
export -f handle_error log_progress log_progress_done  
export -f init_logging cleanup_logging