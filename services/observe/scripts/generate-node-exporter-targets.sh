#!/bin/bash

# Generate node-exporter targets configuration file for Prometheus file-based service discovery.
#
# Usage:
#   generate-node-exporter-targets.sh [options]
#
# Options:
#   --targets "host1:port1" "host2:port2"    Specify VM targets (space-separated, quoted)
#   --instance <instance>                    Specify instance name (required)
#   --env <environment>                      Set environment (default: prod)
#   --project <project>                      Set project name (default: SMC)
#   --manager <manager>                      Set manager name (default: Destrier)
#   --output <path>                          Output file path (default: config/prometheus/targets/node-exporter/$instance.yaml)
#   --help                                    Show this help message
#
# Examples:
#   # Generate with command-line targets and instance
#   generate-node-exporter-targets.sh --instance "vm-cluster-01" --targets "vm1.example.com:9100" "vm2.example.com:9100"
#
#   # Generate with environment variables
#   NODE_EXPORTER_INSTANCE="vm-cluster-01" NODE_EXPORTER_TARGETS="vm1.example.com:9100 vm2.example.com:9100" generate-node-exporter-targets.sh
#
#   # Generate for different environment
#   generate-node-exporter-targets.sh --env staging --instance "services" --targets "staging-vm1:9100" "staging-vm2:9100"

set -e

# Default values
ENVIRONMENT="prod"
PROJECT="SMC"
MANAGER="Destrier"
INSTANCE=""
TARGETS=()
OUTPUT_FILE=""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBSERVE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# Note: DEFAULT_OUTPUT_FILE will be set after INSTANCE is determined
DEFAULT_OUTPUT_FILE=""

# Function to show usage
show_help() {
    cat << EOF
Generate node-exporter targets configuration file for Prometheus file-based service discovery.

Usage:
    $0 [options]

Options:
    --targets "host1:port1" "host2:port2"    Specify VM targets (space-separated, quoted)
    --instance <instance>                     Specify instance name (required)
    --env <environment>                      Set environment (default: prod)
    --project <project>                      Set project name (default: SMC)
    --manager <manager>                      Set manager name (default: Destrier)
    --output <path>                          Output file path (default: config/prometheus/targets/node-exporter/\$instance.yaml)
    --help                                    Show this help message

Examples:
    # Generate with command-line targets and instance
    $0 --instance "vm-cluster-01" --targets "vm1.example.com:9100" "vm2.example.com:9100"

    # Generate with environment variables
    NODE_EXPORTER_INSTANCE="vm-cluster-01" NODE_EXPORTER_TARGETS="vm1.example.com:9100 vm2.example.com:9100" $0

    # Generate for different environment
    $0 --env staging --instance "services" --targets "staging-vm1:9100" "staging-vm2:9100"
EOF
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --targets)
            shift
            while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                TARGETS+=("$1")
                shift
            done
            ;;
        --instance)
            INSTANCE="$2"
            shift 2
            ;;
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --manager)
            MANAGER="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# Use environment variable if instance not provided via command line
if [[ -z "$INSTANCE" ]] && [[ -n "${NODE_EXPORTER_INSTANCE:-}" ]]; then
    INSTANCE="$NODE_EXPORTER_INSTANCE"
fi

# Use environment variable if targets not provided via command line
if [[ ${#TARGETS[@]} -eq 0 ]] && [[ -n "${NODE_EXPORTER_TARGETS:-}" ]]; then
    # Split environment variable by spaces
    read -ra TARGETS <<< "$NODE_EXPORTER_TARGETS"
fi

# Validate instance (required)
if [[ -z "$INSTANCE" ]]; then
    echo "Error: Instance is required. Use --instance option or NODE_EXPORTER_INSTANCE environment variable." >&2
    show_help
    exit 1
fi

# Set default output file if not specified (after instance is validated)
if [[ -z "$DEFAULT_OUTPUT_FILE" ]]; then
    DEFAULT_OUTPUT_FILE="$OBSERVE_DIR/config/prometheus/targets/node-exporter/${INSTANCE}.yaml"
fi

# Validate targets
if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "Error: No targets specified. Use --targets option or NODE_EXPORTER_TARGETS environment variable." >&2
    show_help
    exit 1
fi

# Validate target format (host:port)
for target in "${TARGETS[@]}"; do
    if [[ ! "$target" =~ ^[^:]+:[0-9]+$ ]]; then
        echo "Error: Invalid target format '$target'. Expected format: host:port" >&2
        exit 1
    fi
done

# Set output file if not specified
if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="$DEFAULT_OUTPUT_FILE"
fi

# Create output directory if it doesn't exist (ensure node-exporter subdirectory exists)
OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR"

# Generate YAML content
cat > "$OUTPUT_FILE" << EOF
- labels:
    project: ${PROJECT}
    env: ${ENVIRONMENT}
    source: node_exporter
    monitoring-scope: internal
    instance_name: "${INSTANCE}"
    manager: "${MANAGER}"
  targets:
EOF

# Add targets
for target in "${TARGETS[@]}"; do
    echo "    - \"${target}\"" >> "$OUTPUT_FILE"
done

# Add trailing newline
echo "" >> "$OUTPUT_FILE"

echo "Successfully generated node-exporter targets file: $OUTPUT_FILE"
echo "Targets configured: ${#TARGETS[@]}"
for target in "${TARGETS[@]}"; do
    echo "  - $target"
done

