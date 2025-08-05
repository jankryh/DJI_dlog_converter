#!/bin/bash
# DJI Processor - Interactive Setup Module
# Interactive configuration wizard and LUT management

# Prevent multiple sourcing
[[ "${_DJI_INTERACTIVE_LOADED:-}" == "true" ]] && return 0
readonly _DJI_INTERACTIVE_LOADED=true

# Source dependencies
[[ "${_DJI_LOGGING_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
[[ "${_DJI_CONFIG_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/config.sh"
[[ "${_DJI_UTILS_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/utils.sh"

# LUT Management Functions
# ======================

# Get LUT file information
get_lut_info() {
    local lut_file="$1"
    
    if [[ ! -f "$lut_file" ]]; then
        echo "❌ LUT file not found: $lut_file"
        return 1
    fi
    
    local size="$(stat -f%z "$lut_file" 2>/dev/null || stat -c%s "$lut_file" 2>/dev/null)"
    local title="$(grep -i '^TITLE' "$lut_file" | head -1 | cut -d'"' -f2 2>/dev/null || echo "Unknown")"
    local lut_size="$(grep -i '^LUT_3D_SIZE' "$lut_file" | head -1 | awk '{print $2}' 2>/dev/null || echo "Unknown")"
    
    echo "📄 $(basename "$lut_file")"
    echo "   📝 Title: $title"
    echo "   📏 Size: $lut_size x $lut_size x $lut_size"
    echo "   💾 File size: $(format_file_size "$size")"
    echo "   📍 Path: $lut_file"
}

# Format file size for display
format_file_size() {
    local size="$1"
    
    if [[ $size -lt 1024 ]]; then
        echo "${size}B"
    elif [[ $size -lt 1048576 ]]; then
        echo "$((size / 1024))KB"
    else
        echo "$((size / 1048576))MB"
    fi
}

# List all available LUT files
list_available_luts() {
    local luts_dir="${1:-./luts}"
    
    log_info "🎨 Available LUT Files in $luts_dir"
    echo "==========================================="
    echo ""
    
    if [[ ! -d "$luts_dir" ]]; then
        log_error "LUTs directory not found: $luts_dir"
        return 1
    fi
    
    local lut_files
    mapfile -t lut_files < <(find "$luts_dir" -name "*.cube" -type f | sort)
    
    if [[ ${#lut_files[@]} -eq 0 ]]; then
        log_warning "No LUT files found in $luts_dir"
        echo "💡 You can add .cube files to this directory"
        return 0
    fi
    
    local count=1
    for lut_file in "${lut_files[@]}"; do
        echo "[$count] $(get_lut_info "$lut_file")"
        echo ""
        ((count++))
    done
    
    echo "Found ${#lut_files[@]} LUT file(s)"
}

# Interactive LUT selection
select_lut_interactive() {
    local luts_dir="${1:-./luts}"
    local current_lut="${2:-$LUT_FILE}"
    
    log_info "🎯 Interactive LUT Selection"
    echo "============================="
    echo ""
    
    if [[ ! -d "$luts_dir" ]]; then
        log_error "LUTs directory not found: $luts_dir"
        return 1
    fi
    
    local lut_files
    mapfile -t lut_files < <(find "$luts_dir" -name "*.cube" -type f | sort)
    
    if [[ ${#lut_files[@]} -eq 0 ]]; then
        log_error "No LUT files found in $luts_dir"
        return 1
    fi
    
    echo "📋 Current LUT: $(basename "$current_lut")"
    echo ""
    echo "Available LUTs:"
    
    local count=1
    for lut_file in "${lut_files[@]}"; do
        local marker=" "
        [[ "$lut_file" == "$current_lut" ]] && marker="*"
        
        echo "$marker[$count] $(basename "$lut_file")"
        local title="$(grep -i '^TITLE' "$lut_file" | head -1 | cut -d'"' -f2 2>/dev/null || echo "No title")"
        echo "     $title"
        ((count++))
    done
    
    echo ""
    echo "[0] Keep current LUT"
    echo "[i] Show detailed info"
    echo "[q] Quit"
    echo ""
    
    while true; do
        read -p "Select LUT (0-$((${#lut_files[@]})), i for info, q to quit): " choice
        
        case "$choice" in
            0)
                echo "✅ Keeping current LUT: $(basename "$current_lut")"
                return 0
                ;;
            [1-9]*)
                if [[ "$choice" -ge 1 && "$choice" -le ${#lut_files[@]} ]]; then
                    local selected_lut="${lut_files[$((choice-1))]}"
                    echo "✅ Selected LUT: $(basename "$selected_lut")"
                    echo "$selected_lut"
                    return 0
                else
                    echo "❌ Invalid selection. Please choose 0-${#lut_files[@]}"
                fi
                ;;
            i|I)
                show_lut_details_menu "${lut_files[@]}"
                ;;
            q|Q)
                echo "❌ Selection cancelled"
                return 1
                ;;
            *)
                echo "❌ Invalid input. Use 0-${#lut_files[@]}, 'i' for info, or 'q' to quit"
                ;;
        esac
    done
}

# Show detailed LUT information menu
show_lut_details_menu() {
    local lut_files=("$@")
    
    echo ""
    echo "📋 LUT Details Menu"
    echo "=================="
    
    local count=1
    for lut_file in "${lut_files[@]}"; do
        echo "[$count] $(basename "$lut_file")"
        ((count++))
    done
    
    echo "[b] Back to selection"
    echo ""
    
    while true; do
        read -p "Select LUT for details (1-${#lut_files[@]}, b to go back): " choice
        
        case "$choice" in
            [1-9]*)
                if [[ "$choice" -ge 1 && "$choice" -le ${#lut_files[@]} ]]; then
                    echo ""
                    get_lut_info "${lut_files[$((choice-1))]}"
                    echo ""
                    read -p "Press Enter to continue..."
                    echo ""
                else
                    echo "❌ Invalid selection. Please choose 1-${#lut_files[@]}"
                fi
                ;;
            b|B)
                return 0
                ;;
            *)
                echo "❌ Invalid input. Use 1-${#lut_files[@]} or 'b' to go back"
                ;;
        esac
    done
}

# Organize LUTs by categories
organize_luts_by_category() {
    local luts_dir="${1:-./luts}"
    
    log_info "🗂️ LUT Organization by Category"
    echo "================================"
    echo ""
    
    if [[ ! -d "$luts_dir" ]]; then
        log_error "LUTs directory not found: $luts_dir"
        return 1
    fi
    
    # Create category directories
    local categories=("drone" "cinematic" "vintage" "color-grading" "custom")
    
    for category in "${categories[@]}"; do
        mkdir -p "$luts_dir/$category"
    done
    
    echo "📁 Created category directories:"
    for category in "${categories[@]}"; do
        echo "   - $luts_dir/$category/"
    done
    
    echo ""
    echo "💡 You can now organize your LUTs by moving them to appropriate categories:"
    echo "   - drone/: LUTs specific to drone footage"
    echo "   - cinematic/: Film-style color grading LUTs"
    echo "   - vintage/: Retro and vintage style LUTs"
    echo "   - color-grading/: Professional color correction LUTs"
    echo "   - custom/: Your custom and experimental LUTs"
    echo ""
    
    # Show current LUTs for organization
    local lut_files
    mapfile -t lut_files < <(find "$luts_dir" -maxdepth 1 -name "*.cube" -type f | sort)
    
    if [[ ${#lut_files[@]} -gt 0 ]]; then
        echo "📋 LUTs ready for organization:"
        for lut_file in "${lut_files[@]}"; do
            echo "   - $(basename "$lut_file")"
        done
        echo ""
        echo "🔧 To organize, move files manually or use the interactive organizer"
    fi
}

# Interactive LUT organizer
interactive_lut_organizer() {
    local luts_dir="${1:-./luts}"
    
    log_info "🎯 Interactive LUT Organizer"
    echo "============================"
    echo ""
    
    # First create categories if they don't exist
    organize_luts_by_category "$luts_dir" > /dev/null
    
    # Find LUTs in root directory
    local lut_files
    mapfile -t lut_files < <(find "$luts_dir" -maxdepth 1 -name "*.cube" -type f | sort)
    
    if [[ ${#lut_files[@]} -eq 0 ]]; then
        echo "✅ All LUTs are already organized in categories!"
        return 0
    fi
    
    echo "📁 Available categories:"
    echo "   [1] drone - Drone-specific LUTs"
    echo "   [2] cinematic - Film-style LUTs"
    echo "   [3] vintage - Retro/vintage LUTs"
    echo "   [4] color-grading - Professional color correction"
    echo "   [5] custom - Custom and experimental LUTs"
    echo "   [s] Skip this file"
    echo "   [q] Quit organizer"
    echo ""
    
    local categories=("drone" "cinematic" "vintage" "color-grading" "custom")
    
    for lut_file in "${lut_files[@]}"; do
        echo "📄 Organizing: $(basename "$lut_file")"
        get_lut_info "$lut_file" | head -3
        echo ""
        
        while true; do
            read -p "Select category (1-5, s to skip, q to quit): " choice
            
            case "$choice" in
                [1-5])
                    local category_index=$((choice-1))
                    local target_category="${categories[$category_index]}"
                    local target_path="$luts_dir/$target_category/$(basename "$lut_file")"
                    
                    if mv "$lut_file" "$target_path"; then
                        echo "✅ Moved to $target_category/"
                    else
                        echo "❌ Failed to move file"
                    fi
                    echo ""
                    break
                    ;;
                s|S)
                    echo "⏭️ Skipped"
                    echo ""
                    break
                    ;;
                q|Q)
                    echo "🛑 Organizer stopped"
                    return 0
                    ;;
                *)
                    echo "❌ Invalid input. Use 1-5, 's' to skip, or 'q' to quit"
                    ;;
            esac
        done
    done
    
    echo "✅ LUT organization completed!"
}

# Show LUT management menu
show_lut_management_menu() {
    local luts_dir="${1:-./luts}"
    
    while true; do
        echo ""
        log_info "🎨 LUT Management Menu"
        echo "======================"
        echo ""
        echo "[1] List available LUTs"
        echo "[2] Select LUT interactively"
        echo "[3] Show LUT details"
        echo "[4] Organize LUTs by category"
        echo "[5] Interactive LUT organizer"
        echo "[6] Create category structure"
        echo "[0] Back to main menu"
        echo ""
        
        read -p "Select option (0-6): " choice
        
        case "$choice" in
            1)
                list_available_luts "$luts_dir"
                ;;
            2)
                local selected
                selected=$(select_lut_interactive "$luts_dir" "$LUT_FILE")
                if [[ $? -eq 0 && -n "$selected" ]]; then
                    echo "💾 To use this LUT, update your config or use: --lut '$selected'"
                fi
                ;;
            3)
                echo ""
                echo "Available LUTs for details:"
                local lut_files
                mapfile -t lut_files < <(find "$luts_dir" -name "*.cube" -type f | sort)
                if [[ ${#lut_files[@]} -gt 0 ]]; then
                    show_lut_details_menu "${lut_files[@]}"
                else
                    echo "❌ No LUT files found"
                fi
                ;;
            4)
                organize_luts_by_category "$luts_dir"
                ;;
            5)
                interactive_lut_organizer "$luts_dir"
                ;;
            6)
                organize_luts_by_category "$luts_dir"
                ;;
            0)
                return 0
                ;;
            *)
                echo "❌ Invalid option. Please choose 0-6"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Interactive setup wizard
run_interactive_setup() {
    log_info "🧙 Interactive DJI Processor Setup Wizard"
    echo "=========================================="
    echo ""
    
    while true; do
        echo "Main Menu:"
        echo "[1] Configuration wizard"
        echo "[2] LUT management"
        echo "[3] System validation"
        echo "[q] Quit"
        echo ""
        
        read -p "Select option (1-3, q to quit): " choice
        
        case "$choice" in
            1)
                echo "📝 Configuration wizard will be implemented in future version."
                echo "💡 For now, use: dji-processor config create"
                ;;
            2)
                show_lut_management_menu
                ;;
            3)
                echo "🔍 System validation will be implemented in future version."
                echo "💡 For now, use: dji-processor validate"
                ;;
            q|Q)
                echo "👋 Goodbye!"
                return 0
                ;;
            *)
                echo "❌ Invalid option. Please choose 1-3 or 'q' to quit"
                ;;
        esac
        
        echo ""
    done
}

log_debug "Interactive setup module with LUT management loaded"

# Export functions
export -f run_interactive_setup
export -f show_lut_management_menu
export -f list_available_luts
export -f select_lut_interactive
export -f get_lut_info
export -f organize_luts_by_category
export -f interactive_lut_organizer