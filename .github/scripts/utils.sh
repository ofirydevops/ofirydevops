# scripts/utils.sh
get_dc_service() {
    local dc_service_prefix="$1"
    local node_label="$2"
    local dc_service_suffix="_amd64"

    local node_label_lower=$(echo "$node_label" | tr '[:upper:]' '[:lower:]')

    if [[ "$node_label_lower" == *"arm64"* ]]; then
        dc_service_suffix="_arm64"
    fi

    if [[ "$node_label_lower" == *"gpu"* ]]; then
        dc_service_suffix="${dc_service_suffix}_gpu"
    fi

    local dc_service="${dc_service_prefix}${dc_service_suffix}"
    echo "$dc_service"
}