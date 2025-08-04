#!/bin/bash
# DJI Processor - Video Processing Module
# Core video processing functionality for DJI D-Log to Rec.709 conversion

# Prevent multiple sourcing
[[ "${_DJI_VIDEO_LOADED:-}" == "true" ]] && return 0
readonly _DJI_VIDEO_LOADED=true

# Source dependencies
[[ "${_DJI_LOGGING_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
[[ "${_DJI_CONFIG_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/config.sh"
[[ "${_DJI_UTILS_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/utils.sh"

# Video processing variables
ENCODER="libx264"
HWACCEL=""

# Initialize video processing system
init_video_processing() {
    log_debug "Initializing video processing system"
    
    # Detect hardware acceleration
    local hw_accel
    hw_accel=$(check_hardware_acceleration)
    
    case "$hw_accel" in
        videotoolbox)
            HWACCEL="-hwaccel videotoolbox"
            ENCODER="h264_videotoolbox"
            log_info "✅ Hardware acceleration (VideoToolbox) available"
            ;;
        vaapi)
            HWACCEL="-hwaccel vaapi"
            ENCODER="h264_vaapi"
            log_info "✅ Hardware acceleration (VAAPI) available"
            ;;
        nvenc)
            ENCODER="h264_nvenc"
            log_info "✅ Hardware acceleration (NVENC) available"
            ;;
        *)
            log_warning "Hardware acceleration not available, falling back to software encoding"
            log_info "💡 Software encoding will be slower but still functional"
            ;;
    esac
}

# Enhanced progress bar with ETA
show_video_progress() {
    local current_time=$1
    local duration=$2
    local basename=$3
    local start_time=$4
    local bar_length=${BAR_LENGTH:-50}
    
    local progress=$((current_time * 100 / duration))
    [[ $progress -gt 100 ]] && progress=100
    
    local filled=$((bar_length * progress / 100))
    local empty=$((bar_length - filled))
    
    local filled_bar=$(printf "%0.s#" $(seq 1 $filled 2>/dev/null || printf ""))
    local empty_bar=$(printf "%0.s-" $(seq 1 $empty 2>/dev/null || printf ""))
    
    local eta_info
    eta_info=$(calculate_eta_and_speed "$current_time" "$duration" "$start_time")
    
    # Clear line and display progress with better formatting
    printf "\r\033[K🔄 [%s%s] %3d%% %s%s" "$filled_bar" "$empty_bar" "$progress" "$basename" "$eta_info"
}

# Generate FFmpeg command for video processing
generate_ffmpeg_command() {
    local input_file="$1"
    local output_file="$2"
    local lut_file="${3:-$LUT_FILE}"
    local quality="${4:-$QUALITY_PRESET}"
    
    # Determine encoder to use
    local final_encoder="$ENCODER"
    if [[ "$FORCE_ENCODER" != "auto" ]]; then
        final_encoder="$FORCE_ENCODER"
        [[ "$VERBOSE_LOGGING" == "true" ]] && log_info "🔧 Using forced encoder: $final_encoder"
    fi
    
    # Build FFmpeg command
    local ffmpeg_cmd=(
        ffmpeg -hide_banner -loglevel error -progress pipe:1
        -nostdin
        $HWACCEL -i "$input_file"
        -vf "lut3d='${lut_file}'"
        -c:v "$final_encoder" $(get_quality_settings "$quality")
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
        ffmpeg_cmd+=(-metadata "processed_by=DJI-Processor-v2.0")
        ffmpeg_cmd+=(-metadata "processing_date=$(date -Iseconds)")
        ffmpeg_cmd+=(-metadata "quality_preset=$quality")
    fi
    
    ffmpeg_cmd+=(
        -f mp4  # Explicitly specify MP4 format for .tmp files
        -movflags +faststart  # Optimize for streaming
        -y "$output_file"
    )
    
    # Output the complete command
    printf '%s\0' "${ffmpeg_cmd[@]}"
}

# Get video metadata and validate file
get_video_metadata() {
    local input_file="$1"
    local basename
    basename=$(basename "$input_file")
    
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
    
    # Round duration to integer
    local duration_int
    printf -v duration_int "%.0f" "$duration"
    
    # Output metadata in a parseable format
    echo "duration:$duration_int"
    echo "duration_raw:$duration"
    echo "basename:$basename"
    
    return 0
}

# Validate video file format and codec
validate_video_file() {
    local input_file="$1"
    
    # Check if file exists and is readable
    if [[ ! -f "$input_file" ]] || [[ ! -r "$input_file" ]]; then
        log_error "File not found or not readable: $input_file"
        return 1
    fi
    
    # Check file size constraints
    local file_size_mb
    file_size_mb=$(du -m "$input_file" 2>/dev/null | cut -f1)
    
    # Skip files that are too small
    if [[ ${file_size_mb:-0} -lt ${MIN_FILE_SIZE:-10} ]]; then
        [[ "$VERBOSE_LOGGING" == "true" ]] && log_info "⏭️ Skipping (too small: ${file_size_mb}MB): $(basename "$input_file")"
        return 2  # Special return code for skipped files
    fi
    
    # Skip files that are too large
    if [[ ${MAX_FILE_SIZE:-0} -gt 0 ]]; then
        local file_size_gb=$((file_size_mb / 1024))
        if [[ $file_size_gb -gt $MAX_FILE_SIZE ]]; then
            [[ "$VERBOSE_LOGGING" == "true" ]] && log_info "⏭️ Skipping (too large: ${file_size_gb}GB): $(basename "$input_file")"
            return 2  # Special return code for skipped files
        fi
    fi
    
    # Validate with ffprobe
    if ! ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$input_file" >/dev/null 2>&1; then
        log_error "Invalid video file format: $(basename "$input_file")"
        return 1
    fi
    
    return 0
}

# Process single video file
process_video_file() {
    local input_file="$1"
    local metadata_result
    
    # Validate input file
    if ! validate_video_file "$input_file"; then
        local exit_code=$?
        return $exit_code
    fi
    
    # Get metadata
    if ! metadata_result=$(get_video_metadata "$input_file"); then
        return 1
    fi
    
    # Parse metadata
    local duration_int basename
    while IFS=: read -r key value; do
        case "$key" in
            duration) duration_int="$value" ;;
            basename) basename="$value" ;;
        esac
    done <<< "$metadata_result"
    
    # Determine output path (with date organization if enabled)
    local final_output_dir="$FINAL_DIR"
    if [[ "$ORGANIZE_BY_DATE" == "true" ]]; then
        local file_date
        file_date=$(stat -f "%Sm" -t "$DATE_FORMAT" "$input_file" 2>/dev/null || date +"$DATE_FORMAT")
        final_output_dir="$FINAL_DIR/$file_date"
        mkdir -p "$final_output_dir"
    fi
    
    local output_file="$final_output_dir/$basename"
    local temp_file="$output_file.tmp"
    
    # Skip if already exists and skip_existing is enabled
    if [[ "$SKIP_EXISTING" == "true" && -f "$output_file" ]]; then
        log_info "⏭️ Skipping (already exists): $basename"
        return 0
    fi
    
    # Create backup if enabled
    if [[ "$AUTO_BACKUP" == "true" ]]; then
        mkdir -p "$BACKUP_DIR"
        local backup_path="$BACKUP_DIR/$basename"
        if [[ ! -f "$backup_path" ]]; then
            [[ "$VERBOSE_LOGGING" == "true" ]] && log_info "💾 Creating backup: $backup_path"
            cp "$input_file" "$backup_path" || log_warning "Failed to create backup for $basename"
        fi
    fi
    
    log_info "🎞️ Processing: $basename – duration: ${duration_int}s (quality: $QUALITY_PRESET)"
    
    local start_time
    start_time=$(date +%s)
    
    # Generate FFmpeg command
    local ffmpeg_cmd=()
    while IFS= read -r -d '' arg; do
        ffmpeg_cmd+=("$arg")
    done < <(generate_ffmpeg_command "$input_file" "$temp_file")
    
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
            show_video_progress "$current_time" "$duration_int" "$basename" "$start_time"
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
        return 0
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
            log_info "      ./dji-processor process --verbose"
        fi
        
        return 1
    fi
}

# Find video files in source directory
find_video_files() {
    local source_dir="${1:-$SOURCE_DIR}"
    local temp_file_list="/tmp/dji_files_$$.tmp"
    
    # Default extensions
    local extensions=("mp4" "MP4" "mov" "MOV" "avi" "AVI")
    
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
        find "$source_dir" -type f -iname "*.${ext}" 2>/dev/null >> "$temp_file_list"
    done
    
    # Sort the results and validate files
    sort -u "$temp_file_list" -o "$temp_file_list"
    
    # Filter files by validation
    local valid_files=()
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        if validate_video_file "$file"; then
            valid_files+=("$file")
        fi
    done < "$temp_file_list"
    rm -f "$temp_file_list"
    
    # Output file list
    if [[ ${#valid_files[@]} -gt 0 ]]; then
        printf '%s\n' "${valid_files[@]}"
    fi
}

log_debug "Video processing module loaded"

# Export functions for use in other modules
export -f init_video_processing show_video_progress generate_ffmpeg_command
export -f get_video_metadata validate_video_file process_video_file find_video_files