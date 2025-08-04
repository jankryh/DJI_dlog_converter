#!/bin/bash
# DJI Processor - Filesystem Operations Module
# Handles file system related operations like disk space checking and file organization

# Prevent multiple sourcing
[[ "${_DJI_FILESYSTEM_LOADED:-}" == "true" ]] && return 0
readonly _DJI_FILESYSTEM_LOADED=true

# Source dependencies
[[ "${_DJI_LOGGING_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
[[ "${_DJI_CONFIG_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/config.sh"

# Check available disk space
# Usage: check_disk_space <directory> [minimum_gb]
check_disk_space() {
    local target_dir="$1"
    local min_space_gb="${2:-5}"  # Default minimum 5GB
    
    if [[ ! -d "$target_dir" ]]; then
        log_error "Directory does not exist: $target_dir"
        return 1
    fi
    
    # Get available space in bytes (works on both macOS and Linux)
    local available_bytes
    if command -v df >/dev/null 2>&1; then
        available_bytes=$(df "$target_dir" | tail -1 | awk '{print $4}')
        # Convert from 512-byte blocks to bytes on macOS, or from KB to bytes on Linux
        if [[ "$(uname)" == "Darwin" ]]; then
            available_bytes=$((available_bytes * 512))
        else
            available_bytes=$((available_bytes * 1024))
        fi
    else
        log_error "Cannot determine disk space - df command not available"
        return 1
    fi
    
    # Convert to GB
    local available_gb=$((available_bytes / 1024 / 1024 / 1024))
    local min_space_bytes=$((min_space_gb * 1024 * 1024 * 1024))
    
    log_info "💾 Available disk space: ${available_gb}GB in $target_dir"
    
    if [[ $available_bytes -lt $min_space_bytes ]]; then
        log_warning "⚠️ Low disk space! Available: ${available_gb}GB, Recommended: ${min_space_gb}GB"
        log_info "💡 Consider freeing up space or changing output directory"
        return 1
    fi
    
    return 0
}

# Create directory with date organization
# Usage: create_organized_output_path <base_dir> <input_file>
create_organized_output_path() {
    local base_dir="$1"
    local input_file="$2"
    
    if [[ "$ORGANIZE_BY_DATE" != "true" ]]; then
        echo "$base_dir"
        return 0
    fi
    
    # Get file modification date or current date as fallback
    local file_date
    if [[ -f "$input_file" ]]; then
        file_date=$(stat -f "%Sm" -t "$DATE_FORMAT" "$input_file" 2>/dev/null || date +"$DATE_FORMAT")
    else
        file_date=$(date +"$DATE_FORMAT")
    fi
    
    local organized_dir="$base_dir/$file_date"
    echo "$organized_dir"
}

# Ensure directory exists with proper permissions
# Usage: ensure_directory <directory_path>
ensure_directory() {
    local dir_path="$1"
    
    if [[ -z "$dir_path" ]]; then
        log_error "Directory path cannot be empty"
        return 1
    fi
    
    if [[ ! -d "$dir_path" ]]; then
        if mkdir -p "$dir_path"; then
            log_info "📁 Created directory: $dir_path"
        else
            log_error "Failed to create directory: $dir_path"
            return 1
        fi
    fi
    
    # Check if directory is writable
    if [[ ! -w "$dir_path" ]]; then
        log_error "Directory is not writable: $dir_path"
        return 1
    fi
    
    return 0
}

# Clean up temporary files
# Usage: cleanup_temp_files <pattern>
cleanup_temp_files() {
    local pattern="${1:-*.tmp}"
    local count=0
    
    # Find and remove temporary files
    while IFS= read -r -d '' temp_file; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
            ((count++))
        fi
    done < <(find . -name "$pattern" -print0 2>/dev/null)
    
    if [[ $count -gt 0 ]]; then
        log_info "🧹 Cleaned up $count temporary file(s)"
    fi
}

# Get file size in human readable format
# Usage: get_file_size <file_path>
get_file_size() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo "0B"
        return 1
    fi
    
    # Use du for human-readable output
    du -h "$file_path" | cut -f1
}

# Check if file meets size requirements
# Usage: validate_file_size <file_path>
validate_file_size() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        return 1
    fi
    
    # Get file size in MB
    local file_size_bytes
    file_size_bytes=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)
    local file_size_mb=$((file_size_bytes / 1024 / 1024))
    
    # Check minimum file size
    if [[ $file_size_mb -lt $MIN_FILE_SIZE ]]; then
        log_debug "File too small: $file_path (${file_size_mb}MB < ${MIN_FILE_SIZE}MB)"
        return 2
    fi
    
    # Check maximum file size (0 means no limit)
    if [[ $MAX_FILE_SIZE -gt 0 ]]; then
        local max_size_mb=$((MAX_FILE_SIZE * 1024))  # Convert GB to MB
        if [[ $file_size_mb -gt $max_size_mb ]]; then
            log_debug "File too large: $file_path (${file_size_mb}MB > ${max_size_mb}MB)"
            return 3
        fi
    fi
    
    return 0
}

# Move file with backup if destination exists
# Usage: safe_move_file <source> <destination>
safe_move_file() {
    local source="$1"
    local destination="$2"
    
    if [[ ! -f "$source" ]]; then
        log_error "Source file does not exist: $source"
        return 1
    fi
    
    # Ensure destination directory exists
    local dest_dir
    dest_dir="$(dirname "$destination")"
    ensure_directory "$dest_dir" || return 1
    
    # If destination exists, create backup
    if [[ -f "$destination" ]]; then
        local backup_file="${destination}.backup.$(date +%s)"
        log_info "🔄 Creating backup: $(basename "$backup_file")"
        mv "$destination" "$backup_file"
    fi
    
    # Move the file
    if mv "$source" "$destination"; then
        log_debug "Moved: $(basename "$source") → $(basename "$destination")"
        return 0
    else
        log_error "Failed to move: $source → $destination"
        return 1
    fi
}

# Calculate directory size
# Usage: get_directory_size <directory_path>
get_directory_size() {
    local dir_path="$1"
    
    if [[ ! -d "$dir_path" ]]; then
        echo "0B"
        return 1
    fi
    
    du -sh "$dir_path" | cut -f1
}

log_debug "Filesystem operations module loaded"

# Export functions for use in other modules
export -f check_disk_space create_organized_output_path ensure_directory
export -f cleanup_temp_files get_file_size validate_file_size
export -f safe_move_file get_directory_size