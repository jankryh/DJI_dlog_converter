#!/bin/bash
# DJI Processor - Core Utilities Module
# Common utility functions for DJI video processing

# Prevent multiple sourcing
[[ "${_DJI_UTILS_LOADED:-}" == "true" ]] && return 0
readonly _DJI_UTILS_LOADED=true

# Source logging if not already loaded
[[ "${_DJI_LOGGING_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Quality presets for video encoding
get_quality_settings() {
    local quality="$1"
    local encoder="${ENCODER:-libx264}"
    
    # VideoToolbox uses different parameters than x264
    if [[ "$encoder" == "h264_videotoolbox" ]]; then
        case "$quality" in
            draft)
                echo "-q:v 80 -realtime 1"
                ;;
            standard)
                echo "-q:v 65"
                ;;
            high)
                echo "-q:v 50"  
                ;;
            professional)
                echo "-q:v 35"
                ;;
            *)
                echo "-q:v 65"  # default to standard
                ;;
        esac
    else
        # Standard x264/software encoding
        case "$quality" in
            draft)
                echo "-crf 28 -preset ultrafast"
                ;;
            standard)
                echo "-crf 23 -preset medium"
                ;;
            high)
                echo "-crf 20 -preset slow"  
                ;;
            professional)
                echo "-crf 18 -preset veryslow"
                ;;
            *)
                echo "-crf 23 -preset medium"  # default to standard
                ;;
        esac
    fi
}

# Check system dependencies
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
            log_error "Missing required dependency: $dep"
            case "$dep" in
                ffmpeg)
                    log_info "💡 Install FFmpeg:"
                    log_info "   macOS: brew install ffmpeg"
                    log_info "   Linux: sudo apt-get install ffmpeg"
                    ;;
                *)
                    log_info "💡 Please install $dep and try again"
                    ;;
            esac
        done
        return 1  # Return error code instead of exiting
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

# Validation functions for user inputs
validate_directory() {
    local dir="$1"
    if [[ -z "$dir" ]]; then
        echo "Directory path cannot be empty"
        return 1
    fi
    if [[ ! -d "$dir" ]]; then
        echo "Directory does not exist: $dir"
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
    if [[ ! -f "$file" ]]; then
        echo "File does not exist: $file"
        return 1
    fi
    return 0
}

validate_quality() {
    local quality="$1"
    case "$quality" in
        draft|standard|high|professional) return 0 ;;
        *) echo "Quality must be 'draft', 'standard', 'high', or 'professional'"; return 1 ;;
    esac
}

validate_parallel() {
    local parallel="$1"
    if [[ "$parallel" == "auto" ]]; then
        return 0
    elif [[ "$parallel" =~ ^[0-9]+$ ]] && [[ $parallel -ge 1 ]] && [[ $parallel -le 32 ]]; then
        return 0
    else
        echo "Parallel jobs must be 'auto' or a number between 1-32"
        return 1
    fi
}

# Helper function to convert to lowercase (bash 3.2 compatible)
_to_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

validate_yes_no() {
    local answer="$1"
    local lower_answer
    lower_answer=$(_to_lowercase "$answer")
    case "$lower_answer" in
        y|yes|true) echo "true"; return 0 ;;
        n|no|false) echo "false"; return 0 ;;
        *) echo "Please answer 'y' for yes or 'n' for no"; return 1 ;;
    esac
}

# Calculate estimated time remaining and speed info
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
    local bar_length=${5:-50}
    
    local progress=$((current_time * 100 / duration))
    [[ $progress -gt 100 ]] && progress=100
    
    local filled=$((bar_length * progress / 100))
    local empty=$((bar_length - filled))
    
    local filled_bar=$(printf "%0.s#" $(seq 1 $filled 2>/dev/null || printf ""))
    local empty_bar=$(printf "%0.s-" $(seq 1 $empty 2>/dev/null || printf ""))
    
    local progress_text
    progress_text=$(printf "\r🎬 %s [%s%s] %d%%" "$basename" "$filled_bar" "$empty_bar" "$progress")
    
    # Add ETA and speed info
    local eta_info
    eta_info=$(calculate_eta_and_speed "$current_time" "$duration" "$start_time")
    
    printf "%s%s" "$progress_text" "$eta_info"
}

# Format file size in human readable format
format_file_size() {
    local size_bytes="$1"
    
    if [[ $size_bytes -ge 1073741824 ]]; then
        printf "%.1fG" "$((size_bytes * 10 / 1073741824))e-1"
    elif [[ $size_bytes -ge 1048576 ]]; then
        printf "%.1fM" "$((size_bytes * 10 / 1048576))e-1"
    elif [[ $size_bytes -ge 1024 ]]; then
        printf "%.1fK" "$((size_bytes * 10 / 1024))e-1"
    else
        printf "%dB" "$size_bytes"
    fi
}

# Format duration in human readable format
format_duration() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    local result=""
    
    if [[ $hours -gt 0 ]]; then
        result="${hours}h"
        if [[ $minutes -gt 0 ]]; then
            result="$result ${minutes}m"
        fi
        if [[ $secs -gt 0 ]]; then
            result="$result ${secs}s"
        fi
    elif [[ $minutes -gt 0 ]]; then
        result="${minutes}m"
        if [[ $secs -gt 0 ]]; then
            result="$result ${secs}s"
        fi
    else
        result="${secs}s"
    fi
    
    echo "$result"
}

# Detect platform (macOS or Linux)
detect_platform() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "macos"
    elif [[ "$(uname)" == "Linux" ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# Get number of CPU cores
get_cpu_cores() {
    local platform
    platform=$(detect_platform)
    
    case "$platform" in
        macos)
            sysctl -n hw.ncpu 2>/dev/null || echo "4"
            ;;
        linux)
            nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "4"
            ;;
        *)
            echo "4"  # Default fallback
            ;;
    esac
}

# Check available disk space in bytes
get_available_space() {
    local directory="$1"
    
    if [[ ! -d "$directory" ]]; then
        echo "0"
        return 1
    fi
    
    local platform
    platform=$(detect_platform)
    
    case "$platform" in
        macos)
            df "$directory" 2>/dev/null | awk 'NR==2 {print $4 * 1024}' || echo "0"
            ;;
        linux)
            df "$directory" 2>/dev/null | awk 'NR==2 {print $4 * 1024}' || echo "0"
            ;;
        *)
            echo "0"
            ;;
    esac
}

# Check if hardware acceleration is available
check_hardware_acceleration() {
    local platform
    platform=$(detect_platform)
    
    case "$platform" in
        macos)
            if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q videotoolbox; then
                echo "videotoolbox"
                return 0
            fi
            ;;
        linux)
            if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q vaapi; then
                echo "vaapi"
                return 0
            elif ffmpeg -hide_banner -encoders 2>/dev/null | grep -q nvenc; then
                echo "nvenc"
                return 0
            fi
            ;;
    esac
    
    echo "none"
    return 1
}

# Cleanup temporary files
cleanup_temp_files() {
    local temp_pattern="${1:-/tmp/dji_*}"
    
    # Clean up any temp files matching the pattern
    for temp_file in $temp_pattern; do
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
    done
}

# Export functions for use in other modules
export -f get_quality_settings check_dependencies
export -f validate_directory validate_file validate_quality validate_parallel validate_yes_no
export -f calculate_eta_and_speed show_progress
export -f format_file_size format_duration
export -f detect_platform get_cpu_cores get_available_space
export -f check_hardware_acceleration cleanup_temp_files