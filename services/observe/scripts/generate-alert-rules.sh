#!/bin/bash

# Generate Prometheus alert rules from catalog modules based on project selections.
#
# Usage:
#   generate-alert-rules.sh <project> <environment> [--selection-file <path>]
#   generate-alert-rules.sh <project> <environment> --categories "Category1" "Category2"
#
# Example:
#   generate-alert-rules.sh core-system prod
#   generate-alert-rules.sh core-system dev --categories "Endpoint-Availability" "Endpoint-Latency"

set -e

# Category name to catalog file mapping
# Note: Using function instead of associative array to handle spaces in keys
get_catalog_filename() {
    case "$1" in
        "Endpoint-Availability")
            echo "endpoint-availability.yml"
            ;;
        "Endpoint-Status Code")
            echo "endpoint-status-code.yml"
            ;;
        "Endpoint-Latency")
            echo "endpoint-latency.yml"
            ;;
        "SSL-Certificate")
            echo "ssl-certificate.yml"
            ;;
        *)
            echo ""
            ;;
    esac
}

get_available_categories() {
    echo "Endpoint-Availability Endpoint-Status Code Endpoint-Latency SSL-Certificate"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBSERVE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG_DIR="$OBSERVE_DIR/config/prometheus/base/rules"

# Parse arguments
PROJECT=""
ENVIRONMENT=""
SELECTION_FILE=""
OUTPUT_FILE=""
CATEGORIES=()

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --selection-file)
                SELECTION_FILE="$2"
                shift 2
                ;;
            --output-file)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --categories)
                shift
                while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                    CATEGORIES+=("$1")
                    shift
                done
                ;;
            *)
                if [[ -z "$PROJECT" ]]; then
                    PROJECT="$1"
                elif [[ -z "$ENVIRONMENT" ]]; then
                    ENVIRONMENT="$1"
                else
                    echo "Error: Unknown argument: $1" >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$PROJECT" ]] || [[ -z "$ENVIRONMENT" ]]; then
        echo "Error: Project and environment are required" >&2
        echo "Usage: $0 <project> <environment> [options]" >&2
        exit 1
    fi
}

get_selection_file() {
    if [[ -n "$SELECTION_FILE" ]]; then
        echo "$SELECTION_FILE"
    else
        echo "$OBSERVE_DIR/config/prometheus/rules/selections/$PROJECT/$ENVIRONMENT.yml"
    fi
}

get_output_file() {
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$OUTPUT_FILE"
    else
        echo "$OBSERVE_DIR/config/prometheus/rules/projects/$PROJECT/$ENVIRONMENT.yml"
    fi
}

load_categories_from_selection() {
    local selection_file="$1"
    
    if [[ ! -f "$selection_file" ]]; then
        echo "Error: Selection file not found: $selection_file" >&2
        echo "Available categories: $(get_available_categories)" >&2
        exit 1
    fi

    # Extract categories from YAML file
    # Look for lines with "- " followed by category name
    local in_categories=false
    while IFS= read -r line; do
        # Check if we're in the categories section
        if [[ "$line" =~ ^categories: ]]; then
            in_categories=true
            continue
        fi
        
        # Stop if we hit another top-level key
        if [[ "$in_categories" == true ]] && [[ "$line" =~ ^[a-zA-Z] ]]; then
            break
        fi
        
        # Extract category name (handle both "- Category" and "  - Category" formats)
        if [[ "$in_categories" == true ]] && [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.+)$ ]]; then
            local category="${BASH_REMATCH[1]}"
            # Remove quotes if present
            category="${category//\"/}"
            category="${category//\'/}"
            CATEGORIES+=("$category")
        fi
    done < "$selection_file"

    if [[ ${#CATEGORIES[@]} -eq 0 ]]; then
        echo "Warning: No categories found in selection file" >&2
    fi
}

merge_yaml_groups() {
    local output_file="$1"
    local project="$2"
    local env="$3"
    shift 3
    local catalog_files=("$@")
    
    # Create project-specific prefix for group names
    local group_prefix="${project}_${env}"
    
    # Start with groups array
    echo "groups:" > "$output_file"
    
    # Merge all groups from catalog files
    for catalog_file in "${catalog_files[@]}"; do
        if [[ ! -f "$catalog_file" ]]; then
            echo "Warning: Catalog file not found: $catalog_file" >&2
            continue
        fi
        
        # Extract groups section from YAML file and add project prefix to group names
        local in_groups=false
        local in_group_name=false
        local group_indent=""
        
        while IFS= read -r line; do
            # Check if we're entering groups section
            if [[ "$line" =~ ^groups: ]]; then
                in_groups=true
                continue
            fi
            
            # Stop if we hit another top-level key (not indented)
            if [[ "$in_groups" == true ]] && [[ "$line" =~ ^[a-zA-Z] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
                break
            fi
            
            # Output lines that are part of groups section
            if [[ "$in_groups" == true ]]; then
                # Check if this is a group name line (e.g., "  - name: endpoint_availability")
                if [[ "$line" =~ ^([[:space:]]*-[[:space:]]+name:[[:space:]]+)(.+)$ ]]; then
                    local prefix="${BASH_REMATCH[1]}"
                    local original_name="${BASH_REMATCH[2]}"
                    # Remove quotes if present
                    original_name="${original_name//\"/}"
                    original_name="${original_name//\'/}"
                    # Add project prefix
                    echo "${prefix}${group_prefix}_${original_name}" >> "$output_file"
                else
                    # Output other lines as-is
                    echo "$line" >> "$output_file"
                fi
            fi
        done < "$catalog_file"
    done
}

main() {
    parse_args "$@"
    
    # Check catalog directory
    if [[ ! -d "$CATALOG_DIR" ]]; then
        echo "Error: Catalog directory not found: $CATALOG_DIR" >&2
        exit 1
    fi
    
    # Get categories
    if [[ ${#CATEGORIES[@]} -eq 0 ]]; then
        local selection_file
        selection_file=$(get_selection_file)
        load_categories_from_selection "$selection_file"
    fi
    
    if [[ ${#CATEGORIES[@]} -eq 0 ]]; then
        echo "Error: No categories specified" >&2
        exit 1
    fi
    
    # Map categories to catalog files
    local catalog_files=()
    for category in "${CATEGORIES[@]}"; do
        local filename
        filename=$(get_catalog_filename "$category")
        if [[ -z "$filename" ]]; then
            echo "Warning: Unknown category '$category', skipping" >&2
            continue
        fi
        
        local catalog_file="$CATALOG_DIR/$filename"
        if [[ -f "$catalog_file" ]]; then
            catalog_files+=("$catalog_file")
        else
            echo "Warning: Catalog file not found: $catalog_file" >&2
        fi
    done
    
    if [[ ${#catalog_files[@]} -eq 0 ]]; then
        echo "Error: No valid catalog files found" >&2
        exit 1
    fi
    
    # Generate output file
    local output_file
    output_file=$(get_output_file)
    mkdir -p "$(dirname "$output_file")"
    
    # Merge catalog files with project-specific group names
    merge_yaml_groups "$output_file" "$PROJECT" "$ENVIRONMENT" "${catalog_files[@]}"
    
    echo "Generated alert rules: $output_file"
    echo "Categories included: ${CATEGORIES[*]}"
}

main "$@"

