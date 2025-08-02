#!/bin/bash

# DJI Avata 2 D-Log to Rec.709 Video Processor - Optimized Version
# Processes DJI D-Log video files using hardware acceleration and LUT

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
SOURCE_DIR="${1:-/Users/onimalu/Movies/DJI/source}"
FINAL_DIR="${2:-/Users/onimalu/Movies/DJI/final}"
LUT_FILE="${3:-/Users/onimalu/Movies/DJI/Avata2.cube}"
BAR_LENGTH=50
QUALITY_PRESET="${QUALITY_PRESET:-high}"  # high, medium, low
PARALLEL_JOBS="${PARALLEL_JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo "2")}"  # Auto-detect CPU cores, fallback to 2

# Parallel processing variables
declare -a RUNNING_JOBS=()
declare -a JOB_FILES=()
JOB_COUNTER=0

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

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    command -v ffmpeg >/dev/null 2>&1 || missing_deps+=("ffmpeg")
    command -v ffprobe >/dev/null 2>&1 || missing_deps+=("ffprobe")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Install with: brew install ffmpeg"
        exit 1
    fi
}

# Validate inputs
validate_inputs() {
    [[ -d "$SOURCE_DIR" ]] || { log_error "Source directory not found: $SOURCE_DIR"; exit 1; }
    [[ -f "$LUT_FILE" ]] || { log_error "LUT file not found: $LUT_FILE"; exit 1; }
    
    # Check if videotoolbox is available
    if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q h264_videotoolbox; then
        log_warning "Hardware acceleration (videotoolbox) not available, falling back to software encoding"
        ENCODER="libx264"
        HWACCEL=""
    else
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
    
    # Skip if already exists
    if [[ -f "$output_file" ]]; then
        log_info "⏭️ Skipping (already exists): $basename"
        return 0
    fi
    
    # Get duration
    local duration
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)
    if [[ -z "$duration" || "$duration" == "N/A" ]]; then
        log_error "Cannot determine video duration: $basename"
        return 1
    fi
    
    local duration_int
    printf -v duration_int "%.0f" "$duration"
    
    log_info "🎞️ Processing: $basename – duration: ${duration_int}s (quality: $QUALITY_PRESET)"
    
    local start_time
    start_time=$(date +%s)
    
    # FFmpeg command with error handling
    local ffmpeg_cmd=(
        ffmpeg -hide_banner -loglevel error -progress pipe:1
        -nostdin
        $HWACCEL -i "$input_file"
        -vf "lut3d='${LUT_FILE}'"
        -c:v "$ENCODER" $(get_quality_settings "$QUALITY_PRESET")
        -c:a copy
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
        
        log_success "Hotovo: $basename"
        log_info "Size: $size | Time: $(printf "%02d:%02d" "$proc_min" "$proc_sec")"
    else
        # Error - cleanup temp file
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
        echo ""  # New line after progress bar
        log_error "Error processing: $basename"
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
        
        # Cleanup log file
        rm -f "$log_file"
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
    log_info "🚀 DJI Avata 2 D-Log Processor (Optimized) - Parallel Edition"
    log_info "Source directory: $SOURCE_DIR"
    log_info "Output directory: $FINAL_DIR"
    log_info "LUT file: $LUT_FILE"
    log_info "Quality: $QUALITY_PRESET"
    log_info "Parallel jobs: $PARALLEL_JOBS"
    
    check_dependencies
    validate_inputs
    
    mkdir -p "$FINAL_DIR"
    
    # Find all MP4 files (bash 3.2 compatible)
    FILES=()
    local temp_file_list="/tmp/dji_files_$$.tmp"
    find "$SOURCE_DIR" -type f \( -iname "*.mp4" -o -iname "*.MP4" -o -iname "*.Mp4" -o -iname "*.mP4" \) | sort > "$temp_file_list"
    while IFS= read -r file; do
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
}

# Handle interruption gracefully
trap 'echo ""; log_warning "Processing interrupted by user"; cleanup_jobs; exit 130' INT TERM

# Show usage if help requested
if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    cat << EOF
Použití: $0 [ZDROJOVÁ_SLOŽKA] [VÝSTUPNÍ_SLOŽKA] [LUT_SOUBOR]

DJI Avata 2 D-Log to Rec.709 Video Processor s paralelním zpracováním

Proměnné prostředí:
  QUALITY_PRESET   Kvalita: high, medium, low (výchozí: high)
  PARALLEL_JOBS    Počet paralelních úloh (výchozí: auto-detect CPU cores)

Příklady:
  $0                                    # Použije výchozí cesty, auto-detect cores
  QUALITY_PRESET=medium $0              # Střední kvalita
  PARALLEL_JOBS=4 $0                    # 4 paralelní úlohy
  PARALLEL_JOBS=1 $0                    # Sekvenční zpracování
  $0 /path/to/source /path/to/output    # Vlastní cesty

Poznámky:
  - Paralelní zpracování zrychlí konverzi více souborů
  - Každá úloha používá všechny dostupné CPU cores
  - Pro 1 soubor použijte PARALLEL_JOBS=1
  - Pro více souborů doporučujeme 2-4 paralelní úlohy
EOF
    exit 0
fi

# Run main function
main "$@"