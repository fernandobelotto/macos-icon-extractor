#!/bin/bash

# =============================================================================
# macOS Application Icon Extractor
# =============================================================================
# Extracts application icons from macOS apps and converts them to PNG format
# at the highest available resolution (typically 1024x1024)
# =============================================================================

set -euo pipefail

# Configuration
OUTPUT_DIR="${1:-./app_icons}"
SEARCH_DIRS=("/Applications" "$HOME/Applications" "/System/Applications")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_HELPER="$SCRIPT_DIR/extract-icon"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counters
total_apps=0
successful=0
failed=0
skipped=0

# Arrays to track results
declare -a failed_apps=()
declare -a skipped_apps=()

# Print banner
print_banner() {
    echo -e "${BOLD}${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         macOS Application Icon Extractor                      ║"
    echo "║         Converting .icns to high-resolution PNG               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Log functions
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_progress() {
    echo -e "${BLUE}[→]${NC} $1"
}

# Get icon file path from an application bundle
get_icon_path() {
    local app_path="$1"
    local info_plist="$app_path/Contents/Info.plist"
    local resources_dir="$app_path/Contents/Resources"

    # Try to get icon name from Info.plist
    if [[ -f "$info_plist" ]]; then
        local icon_name
        icon_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$info_plist" 2>/dev/null || echo "")

        if [[ -n "$icon_name" ]]; then
            # Add .icns extension if not present
            [[ "$icon_name" != *.icns ]] && icon_name="${icon_name}.icns"

            local icon_path="$resources_dir/$icon_name"
            if [[ -f "$icon_path" ]]; then
                echo "$icon_path"
                return 0
            fi
        fi
    fi

    # Fallback: search for common icon names in Resources
    local common_names=("AppIcon.icns" "icon.icns" "app.icns" "Icon.icns")
    for name in "${common_names[@]}"; do
        if [[ -f "$resources_dir/$name" ]]; then
            echo "$resources_dir/$name"
            return 0
        fi
    done

    # Last resort: find any .icns file
    local icns_file
    icns_file=$(find "$resources_dir" -maxdepth 1 -name "*.icns" -type f 2>/dev/null | head -1)
    if [[ -n "$icns_file" ]]; then
        echo "$icns_file"
        return 0
    fi

    return 1
}

# Sanitize filename (remove special characters)
sanitize_filename() {
    local name="$1"
    # Remove .app extension and sanitize
    name="${name%.app}"
    # Replace problematic characters with underscores
    echo "$name" | tr '/:' '_'
}

# Extract icon from a single application
extract_icon() {
    local app_path="$1"
    local app_name
    app_name=$(basename "$app_path")
    local safe_name
    safe_name=$(sanitize_filename "$app_name")
    local output_file="$OUTPUT_DIR/${safe_name}.png"

    ((total_apps++))

    # Check if output already exists
    if [[ -f "$output_file" ]]; then
        log_warning "Skipped (already exists): $app_name"
        skipped_apps+=("$app_name")
        ((skipped++))
        return 0
    fi

    # Try Method 1: Get icon path from .icns file
    local icon_path
    if icon_path=$(get_icon_path "$app_path") 2>/dev/null; then
        # Convert to PNG using sips
        if sips -s format png "$icon_path" --out "$output_file" &>/dev/null; then
            local dimensions
            dimensions=$(sips -g pixelWidth -g pixelHeight "$output_file" 2>/dev/null | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
            log_success "Extracted: $app_name → ${safe_name}.png (${dimensions})"
            ((successful++))
            return 0
        fi
    fi

    # Try Method 2: Use Swift helper for Asset Catalog icons
    if [[ -x "$SWIFT_HELPER" ]]; then
        if "$SWIFT_HELPER" "$app_path" "$output_file" &>/dev/null; then
            local dimensions
            dimensions=$(sips -g pixelWidth -g pixelHeight "$output_file" 2>/dev/null | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
            log_success "Extracted: $app_name → ${safe_name}.png (${dimensions}) [Asset Catalog]"
            ((successful++))
            return 0
        fi
    fi

    # Both methods failed
    log_error "No icon found: $app_name"
    failed_apps+=("$app_name (no icon file)")
    ((failed++))
    return 1
}

# Find and process all applications
process_applications() {
    local apps=()

    log_info "Scanning for applications..."
    echo ""

    # Find all .app bundles
    for search_dir in "${SEARCH_DIRS[@]}"; do
        if [[ -d "$search_dir" ]]; then
            log_info "Searching: $search_dir"
            while IFS= read -r -d '' app; do
                apps+=("$app")
            done < <(find "$search_dir" -maxdepth 1 -name "*.app" -type d -print0 2>/dev/null)
        fi
    done

    local app_count=${#apps[@]}
    echo ""
    log_info "Found ${BOLD}$app_count${NC} applications to process"
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Process each application
    local current=0
    for app in "${apps[@]}"; do
        ((current++))
        printf "${BLUE}[%3d/%3d]${NC} " "$current" "$app_count"
        extract_icon "$app" || true  # Continue even if extraction fails
    done
}

# Print summary
print_summary() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                         SUMMARY                               ${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}Total applications found:${NC}  $total_apps"
    echo -e "  ${GREEN}Successfully extracted:${NC}    $successful"
    echo -e "  ${YELLOW}Skipped (already exist):${NC}   $skipped"
    echo -e "  ${RED}Failed:${NC}                    $failed"
    echo ""

    if [[ $successful -gt 0 ]]; then
        echo -e "  ${GREEN}Output directory:${NC} $OUTPUT_DIR"
        local total_size
        total_size=$(du -sh "$OUTPUT_DIR"/*.png 2>/dev/null | tail -1 | awk '{print $1}' || echo "N/A")
        echo -e "  ${GREEN}Total PNG files:${NC} $(ls -1 "$OUTPUT_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')"
    fi

    if [[ ${#failed_apps[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${RED}Failed applications:${NC}"
        for app in "${failed_apps[@]}"; do
            echo -e "    - $app"
        done
    fi

    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

# Main execution
main() {
    print_banner

    # Create output directory if needed
    mkdir -p "$OUTPUT_DIR"

    log_info "Output directory: ${BOLD}$OUTPUT_DIR${NC}"
    echo ""

    # Process all applications
    process_applications

    # Print summary
    print_summary

    # Exit with error code if any failures
    [[ $failed -gt 0 ]] && exit 1
    exit 0
}

# Run main function
main
