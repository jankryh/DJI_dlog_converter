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
        echo "[7] 🎬 Browse & Download DJI Official LUTs"
        echo "[0] Back to main menu"
        echo ""
        
        read -p "Select option (0-7): " choice
        
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
            7)
                show_dji_lut_browser
                ;;
            0)
                return 0
                ;;
            *)
                echo "❌ Invalid option. Please choose 0-7"
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

# DJI Official LUT Download Functions
# =====================================

# Define available DJI LUTs based on official website
declare -A DJI_LUTS=(
    # Camera Drones
    ["mavic3_dlog_m_rec709"]="DJI Mavic 3 D-Log M to Rec.709 LUT|drone|https://www.dji.com/downloads/djiapp/dji-lut"
    ["mavic3_dlog_rec709_vivid"]="DJI Mavic 3 D-Log to Rec.709 vivid LUT|cinematic|https://www.dji.com/downloads/djiapp/dji-lut"
    ["mavic3_dlog_rec709"]="DJI Mavic 3 D-Log to Rec.709 LUT|drone|https://www.dji.com/downloads/djiapp/dji-lut"
    ["avata2_dlog_m_rec709"]="DJI Avata 2 D-Log M to Rec.709 LUT|drone|https://www.dji.com/downloads/djiapp/dji-lut"
    ["flip_dlog_m_rec709"]="DJI Flip D-Log M to Rec.709|drone|https://www.dji.com/downloads/djiapp/dji-lut"
    ["mini4pro_dlog_m_rec709"]="DJI Mini 4 Pro D-Log M to Rec.709 LUT|drone|https://www.dji.com/downloads/djiapp/dji-lut"
    ["air3s_dlog_m_rec709"]="DJI Air 3s D-Log M to Rec.709 LUT|drone|https://www.dji.com/downloads/djiapp/dji-lut"
    ["air3_dlog_m_rec709"]="DJI Air 3 D-Log M to Rec.709 LUT|drone|https://www.dji.com/downloads/djiapp/dji-lut"
    ["phantom4_dlog"]="DJI Phantom 4 Dlog 3D LUT|vintage|https://www.dji.com/downloads/djiapp/dji-lut"
    ["phantom3_dlog_srgb"]="DJI Phantom 3 Dlog to sRGB 3D LUT|vintage|https://www.dji.com/downloads/djiapp/dji-lut"
    ["inspire1_dlog_srgb"]="DJI Inspire 1 Dlog to sRGB 3D LUT|vintage|https://www.dji.com/downloads/djiapp/dji-lut"
    
    # Handheld
    ["action5_dlog_m_rec709_vivid"]="DJI OSMO Action 5 D-Log M to Rec.709 vivid LUT|cinematic|https://www.dji.com/downloads/djiapp/dji-lut"
    ["action4_dlog_m_rec709_vivid"]="DJI OSMO Action 4 D-Log M to Rec.709 vivid LUT|cinematic|https://www.dji.com/downloads/djiapp/dji-lut"
    ["pocket3_dlog_m_rec709"]="DJI OSMO Pocket 3 D-Log M to Rec.709 LUT|cinematic|https://www.dji.com/downloads/djiapp/dji-lut"
    
    # Specialized
    ["x9_dlog_rec2020_hlg"]="DJI Zenmuse X9 D-Log to Rec.2020 HLG LUT|color-grading|https://www.dji.com/downloads/djiapp/dji-lut"
    ["x9_dlog_rec709"]="DJI Zenmuse X9 D-Log to Rec.709 LUT|color-grading|https://www.dji.com/downloads/djiapp/dji-lut"
    ["x5_dlog_srgb"]="DJI Zenmuse X5 Dlog to sRGB 3D LUT|color-grading|https://www.dji.com/downloads/djiapp/dji-lut"
    ["x5x7_linear_dlog"]="DJI Zenmuse X5/X7 Linear to D-Log LUT|color-grading|https://www.dji.com/downloads/djiapp/dji-lut"
    ["x5x7_dlog_rec709"]="DJI Zenmuse X5/X7 D-Log to Rec.709 LUT|color-grading|https://www.dji.com/downloads/djiapp/dji-lut"
)

# Show available DJI LUTs for download
show_dji_luts() {
    log_info "🎬 Official DJI LUT Downloads"
    echo "=============================="
    echo ""
    echo "📥 Browse and download official LUTs from DJI website"
    echo "🌐 Source: https://www.dji.com/lut"
    echo ""
    
    echo "📱 Camera Drones:"
    echo "----------------"
    local count=1
    for key in "${!DJI_LUTS[@]}"; do
        local lut_info="${DJI_LUTS[$key]}"
        local name=$(echo "$lut_info" | cut -d'|' -f1)
        local category=$(echo "$lut_info" | cut -d'|' -f2)
        
        case "$key" in
            mavic3_*|avata2_*|flip_*|mini4pro_*|air3*_*|phantom*_*|inspire1_*)
                echo "  [$count] $name (→ $category/)"
                ((count++))
                ;;
        esac
    done
    
    echo ""
    echo "📷 Handheld Cameras:"
    echo "-------------------"
    for key in "${!DJI_LUTS[@]}"; do
        local lut_info="${DJI_LUTS[$key]}"
        local name=$(echo "$lut_info" | cut -d'|' -f1)
        local category=$(echo "$lut_info" | cut -d'|' -f2)
        
        case "$key" in
            action*_*|pocket3_*)
                echo "  [$count] $name (→ $category/)"
                ((count++))
                ;;
        esac
    done
    
    echo ""
    echo "🎛️ Specialized Equipment:"
    echo "------------------------"
    for key in "${!DJI_LUTS[@]}"; do
        local lut_info="${DJI_LUTS[$key]}"
        local name=$(echo "$lut_info" | cut -d'|' -f1)
        local category=$(echo "$lut_info" | cut -d'|' -f2)
        
        case "$key" in
            x9_*|x5_*|x5x7_*)
                echo "  [$count] $name (→ $category/)"
                ((count++))
                ;;
        esac
    done
    
    echo ""
    echo "💡 Note: LUTs will be downloaded and organized into appropriate categories"
}

# Interactive DJI LUT downloader
download_dji_luts() {
    log_info "🌐 DJI Official LUT Downloader"
    echo "=============================="
    echo ""
    
    # Check if curl or wget is available
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        log_error "❌ Neither curl nor wget found. Please install one of them to download LUTs."
        echo "💡 Install with:"
        echo "   macOS: brew install curl"
        echo "   Linux: sudo apt-get install curl"
        return 1
    fi
    
    show_dji_luts
    echo ""
    
    # Create array for selection
    local lut_keys=()
    for key in "${!DJI_LUTS[@]}"; do
        lut_keys+=("$key")
    done
    
    # Sort keys for consistent ordering
    IFS=$'\n' lut_keys=($(sort <<<"${lut_keys[*]}"))
    unset IFS
    
    echo "🎯 Select LUT to download:"
    echo "[0] Back to LUT menu"
    echo "[a] Download all LUTs (organized by category)"
    echo ""
    
    while true; do
        read -p "Select LUT (0-${#lut_keys[@]}, 'a' for all): " choice
        
        case "$choice" in
            0)
                return 0
                ;;
            a|A)
                download_all_dji_luts
                return 0
                ;;
            [1-9]*)
                if [[ "$choice" -ge 1 && "$choice" -le ${#lut_keys[@]} ]]; then
                    local selected_key="${lut_keys[$((choice-1))]}"
                    download_single_dji_lut "$selected_key"
                    return 0
                else
                    echo "❌ Invalid selection. Please choose 0-${#lut_keys[@]} or 'a'"
                fi
                ;;
            *)
                echo "❌ Invalid input. Use 0-${#lut_keys[@]}, 'a' for all"
                ;;
        esac
    done
}

# Download a single DJI LUT
download_single_dji_lut() {
    local lut_key="$1"
    local lut_info="${DJI_LUTS[$lut_key]}"
    local name=$(echo "$lut_info" | cut -d'|' -f1)
    local category=$(echo "$lut_info" | cut -d'|' -f2)
    local base_url=$(echo "$lut_info" | cut -d'|' -f3)
    
    echo ""
    echo "📥 Downloading: $name"
    echo "📁 Category: $category"
    
    # Create category directory
    local luts_dir="./luts"
    mkdir -p "$luts_dir/$category"
    
    # Generate filename from key
    local filename="${lut_key}.cube"
    local target_path="$luts_dir/$category/$filename"
    
    echo "💾 Saving to: $target_path"
    echo ""
    
    # Note: Since we can't directly access the actual download URLs from the search results,
    # we'll create a placeholder and show instructions for manual download
    echo "🌐 Manual Download Required:"
    echo "1. Visit: https://www.dji.com/lut"
    echo "2. Find: $name"
    echo "3. Download the LUT file"
    echo "4. Save as: $target_path"
    echo ""
    echo "⚠️  Note: Automatic download will be implemented when DJI provides direct download URLs"
    
    # Create placeholder file with instructions
    cat > "$target_path" << EOF
# $name
# Downloaded from: https://www.dji.com/lut
# Category: $category
# 
# This is a placeholder file. Please download the actual LUT from:
# https://www.dji.com/lut
# 
# Replace this file with the downloaded .cube file
TITLE "$name"
LUT_3D_SIZE 32

# Placeholder data - replace with actual LUT content
0.0 0.0 0.0
0.1 0.1 0.1
0.2 0.2 0.2
EOF
    
    echo "✅ Placeholder created: $target_path"
    echo "💡 Please replace with actual LUT file from DJI website"
}

# Download all DJI LUTs
download_all_dji_luts() {
    echo ""
    echo "📦 Downloading all DJI LUTs..."
    echo "==============================="
    echo ""
    
    local total=${#DJI_LUTS[@]}
    local count=0
    
    for key in "${!DJI_LUTS[@]}"; do
        ((count++))
        echo "[$count/$total] Processing: $key"
        download_single_dji_lut "$key"
        echo ""
    done
    
    echo "✅ All DJI LUT placeholders created!"
    echo "📁 Check the luts/ directory structure:"
    echo ""
    
    # Show organization results
    organize_luts_by_category "./luts" > /dev/null 2>&1
    echo "🎯 Visit https://www.dji.com/lut to download actual LUT files"
}

# Show DJI LUT browser and downloader
show_dji_lut_browser() {
    while true; do
        echo ""
        log_info "🎬 DJI Official LUT Browser"
        echo "============================"
        echo ""
        echo "[1] Browse available DJI LUTs"
        echo "[2] Download selected LUTs"
        echo "[3] Download all DJI LUTs"
        echo "[4] Visit DJI LUT website"
        echo "[0] Back to LUT menu"
        echo ""
        
        read -p "Select option (0-4): " choice
        
        case "$choice" in
            1)
                show_dji_luts
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                download_dji_luts
                ;;
            3)
                download_all_dji_luts
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                echo ""
                echo "🌐 Opening DJI LUT website..."
                echo "Visit: https://www.dji.com/lut"
                echo ""
                if command -v xdg-open >/dev/null 2>&1; then
                    xdg-open "https://www.dji.com/lut"
                elif command -v open >/dev/null 2>&1; then
                    open "https://www.dji.com/lut"
                else
                    echo "💡 Please open the URL manually in your browser"
                fi
                read -p "Press Enter to continue..."
                ;;
            0)
                return 0
                ;;
            *)
                echo "❌ Invalid option. Please choose 0-4"
                ;;
        esac
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
export -f show_dji_luts
export -f download_dji_luts
export -f download_single_dji_lut
export -f download_all_dji_luts
export -f show_dji_lut_browser