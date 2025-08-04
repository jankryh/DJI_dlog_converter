#!/bin/bash
# DJI Processor - Parallel Processing Module
# Manages parallel job execution, resource monitoring, and progress tracking

# Prevent multiple sourcing
[[ "${_DJI_PARALLEL_LOADED:-}" == "true" ]] && return 0
readonly _DJI_PARALLEL_LOADED=true

# Source dependencies
[[ "${_DJI_LOGGING_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
[[ "${_DJI_CONFIG_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/config.sh"
[[ "${_DJI_UTILS_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/utils.sh"
[[ "${_DJI_VIDEO_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/video.sh"

# Global parallel processing variables
declare -a RUNNING_JOBS=()
declare -a JOB_FILES=()
declare -i JOB_COUNTER=0
declare -i PROCESSED_COUNT=0
declare -i FAILED_COUNT=0
declare -i SKIPPED_COUNT=0

# Job log directory
JOB_LOG_DIR="/tmp/dji_jobs_$$"

# Initialize parallel processing system
init_parallel_processing() {
    log_debug "Initializing parallel processing system"
    
    # Create job log directory if keeping logs
    if [[ "$KEEP_JOB_LOGS" == "true" ]]; then
        mkdir -p "$JOB_LOG_DIR"
        log_info "💾 Job logs will be saved to: $JOB_LOG_DIR"
    fi
    
    # Reset counters
    JOB_COUNTER=0
    PROCESSED_COUNT=0
    FAILED_COUNT=0
    SKIPPED_COUNT=0
    RUNNING_JOBS=()
    JOB_FILES=()
    
    # Ensure we have proper parallel jobs setting
    if [[ "$PARALLEL_JOBS" == "auto" || "$PARALLEL_JOBS" == "0" ]]; then
        PARALLEL_JOBS=$(get_cpu_cores)
    fi
    
    log_info "🚀 Parallel processing initialized with $PARALLEL_JOBS concurrent jobs"
}

# Wait for an available job slot
wait_for_job_slot() {
    # Wait until we have fewer than PARALLEL_JOBS running
    while [[ ${#RUNNING_JOBS[@]} -ge $PARALLEL_JOBS ]]; do
        check_completed_jobs
        [[ ${#RUNNING_JOBS[@]} -ge $PARALLEL_JOBS ]] && sleep 0.5
    done
}

# Check for completed jobs and update status
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
                local exit_code=$?
                case $exit_code in
                    0) 
                        log_success "✅ Completed: $(basename "$file")"
                        ((PROCESSED_COUNT++))
                        ;;
                    2)
                        log_info "⏭️ Skipped: $(basename "$file")"
                        ((SKIPPED_COUNT++))
                        ;;
                    *)
                        log_error "❌ Error: $(basename "$file")"
                        ((FAILED_COUNT++))
                        ;;
                esac
            else
                log_error "❌ Error: $(basename "$file")"
                ((FAILED_COUNT++))
            fi
        fi
    done
    
    # Handle empty arrays properly to avoid "unbound variable" error
    if [[ ${#new_running_jobs[@]} -gt 0 ]]; then
        RUNNING_JOBS=("${new_running_jobs[@]}")
    else
        RUNNING_JOBS=()
    fi
    
    if [[ ${#new_job_files[@]} -gt 0 ]]; then
        JOB_FILES=("${new_job_files[@]}")
    else
        JOB_FILES=()
    fi
}

# Wait for all running jobs to complete
wait_for_all_jobs() {
    # Wait for all remaining jobs to complete
    while [[ ${#RUNNING_JOBS[@]} -gt 0 ]]; do
        check_completed_jobs
        [[ ${#RUNNING_JOBS[@]} -gt 0 ]] && sleep 1
    done
}

# Start a new parallel job
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

# Show parallel processing status
show_parallel_status() {
    local total_files=$1
    local completed=$((PROCESSED_COUNT + FAILED_COUNT + SKIPPED_COUNT))
    local running=${#RUNNING_JOBS[@]}
    
    echo -ne "\r\033[K"
    printf "📊 Status: %d/%d completed | %d running | %d successful" \
           "$completed" "$total_files" "$running" "$PROCESSED_COUNT"
    
    [[ $SKIPPED_COUNT -gt 0 ]] && printf " | %d skipped" "$SKIPPED_COUNT"
    [[ $FAILED_COUNT -gt 0 ]] && printf " | %d errors" "$FAILED_COUNT"
}

# Process single file for parallel execution (simplified progress)
process_file_parallel() {
    local input_file="$1"
    local job_id="$2"
    local basename
    basename=$(basename "$input_file")
    
    # Create job log file
    local log_file
    if [[ "$KEEP_JOB_LOGS" == "true" ]]; then
        log_file="$JOB_LOG_DIR/job_${job_id}_${basename%.*}.log"
    else
        log_file="/tmp/dji_job_${job_id}_$$.log"
    fi
    
    # Validate input file first
    if ! validate_video_file "$input_file"; then
        local exit_code=$?
        case $exit_code in
            2) 
                echo "⏭️ Skipping (validation failed): $basename" > "$log_file"
                [[ "$KEEP_JOB_LOGS" != "true" ]] && rm -f "$log_file"
                return 2
                ;;
            *)
                echo "❌ Invalid video file: $basename" > "$log_file"
                return 1
                ;;
        esac
    fi
    
    # Use the video processing module function
    if process_video_file "$input_file"; then
        echo "✅ Completed job #$job_id: $basename" >> "$log_file"
        [[ "$KEEP_JOB_LOGS" != "true" ]] && rm -f "$log_file"
        return 0
    else
        local exit_code=$?
        echo "❌ Error processing job #$job_id: $basename" >> "$log_file"
        return $exit_code
    fi
}

# Process multiple files in parallel
process_files_parallel() {
    local video_files=("$@")
    local total=${#video_files[@]}
    
    if [[ $total -eq 0 ]]; then
        log_warning "No video files provided for parallel processing"
        return 0
    fi
    
    # Initialize parallel processing
    init_parallel_processing
    
    log_info "🚀 Parallel processing ($PARALLEL_JOBS jobs simultaneously)"
    log_info "Processing $total files..."
    
    # Record total processing start time
    local total_start_time
    total_start_time=$(date +%s)
    
    # Start initial jobs
    for i in "${!video_files[@]}"; do
        wait_for_job_slot
        start_parallel_job "${video_files[$i]}"
        
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
    
    # Calculate total processing time
    local total_end_time
    total_end_time=$(date +%s)
    local total_processing_time=$((total_end_time - total_start_time))
    local total_min=$((total_processing_time / 60))
    local total_sec=$((total_processing_time % 60))
    
    # Final summary
    echo ""
    log_info "📊 Parallel Processing Summary"
    echo "============================="
    echo "Total files processed: $total"
    echo "Successfully processed: $PROCESSED_COUNT"
    [[ $SKIPPED_COUNT -gt 0 ]] && echo "Skipped: $SKIPPED_COUNT"
    [[ $FAILED_COUNT -gt 0 ]] && echo "Failed: $FAILED_COUNT"
    echo "Total time: $(printf "%02d:%02d" "$total_min" "$total_sec")"
    
    # Show job logs location if kept
    if [[ "$KEEP_JOB_LOGS" == "true" && -d "$JOB_LOG_DIR" ]]; then
        echo ""
        log_info "📁 Job logs saved to: $JOB_LOG_DIR"
    fi
    
    # Return appropriate exit code
    if [[ $FAILED_COUNT -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Cleanup parallel processing resources
cleanup_parallel_processing() {
    # Kill any remaining background jobs
    if [[ ${#RUNNING_JOBS[@]} -gt 0 ]]; then
        log_warning "Cleaning up ${#RUNNING_JOBS[@]} running jobs..."
        for pid in "${RUNNING_JOBS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
            fi
        done
    fi
    
    # Clean up temporary job logs if not keeping them
    if [[ "$KEEP_JOB_LOGS" != "true" ]]; then
        rm -rf "/tmp/dji_job_*_$$.log" 2>/dev/null || true
        rm -rf "$JOB_LOG_DIR" 2>/dev/null || true
    fi
    
    # Reset counters
    RUNNING_JOBS=()
    JOB_FILES=()
    JOB_COUNTER=0
    PROCESSED_COUNT=0
    FAILED_COUNT=0
    SKIPPED_COUNT=0
}

log_debug "Parallel processing module loaded"

# Export functions for use in other modules
export -f init_parallel_processing wait_for_job_slot check_completed_jobs
export -f wait_for_all_jobs start_parallel_job show_parallel_status
export -f process_file_parallel process_files_parallel cleanup_parallel_processing