#!/bin/bash
# DJI Processor - Interactive Setup Module
# Interactive configuration wizard

# Prevent multiple sourcing
[[ "${_DJI_INTERACTIVE_LOADED:-}" == "true" ]] && return 0
readonly _DJI_INTERACTIVE_LOADED=true

# Source dependencies
[[ "${_DJI_LOGGING_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
[[ "${_DJI_CONFIG_LOADED:-}" != "true" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../core/config.sh"

# Interactive setup wizard
run_interactive_setup() {
    log_info "🧙 Interactive DJI Processor Setup Wizard"
    echo "=========================================="
    echo ""
    echo "This wizard will help you configure the DJI video processor."
    echo "Interactive setup will be implemented in future version."
    echo ""
    log_info "💡 For now, use: dji-processor config create"
}

log_debug "Interactive setup module loaded"

# Export functions
export -f run_interactive_setup