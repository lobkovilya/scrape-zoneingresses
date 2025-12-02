#!/bin/bash

# Parse command line arguments
ZONE_FILTER=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --zone)
            ZONE_FILTER="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--zone ZONE_NAME]"
            exit 1
            ;;
    esac
done

# Check if required environment variables are set
if [ -z "$KONNECT_TOKEN" ]; then
    echo "Error: KONNECT_TOKEN environment variable is not set"
    echo "Please set it with: export KONNECT_TOKEN='your-token'"
    exit 1
fi

if [ -z "$KONNECT_API_URL" ]; then
    echo "Error: KONNECT_API_URL environment variable is not set"
    echo "Please set it with: export KONNECT_API_URL='https://api.konghq.com'"
    exit 1
fi

# Remove trailing slash from API URL if present
KONNECT_API_URL="${KONNECT_API_URL%/}"

# Create output directory for XDS files
OUTPUT_DIR="zoneingress_xds_output"
mkdir -p "$OUTPUT_DIR"

if [ -n "$ZONE_FILTER" ]; then
    echo "Fetching zone ingresses from ${KONNECT_API_URL}/zoneingresses (filtering by zone: ${ZONE_FILTER})..."
else
    echo "Fetching zone ingresses from ${KONNECT_API_URL}/zoneingresses..."
fi

# Fetch the list of zone ingresses
RESPONSE=$(curl -s -H "Authorization: Bearer ${KONNECT_TOKEN}" \
    "${KONNECT_API_URL}/zoneingresses")

# Check if curl was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch zone ingresses"
    exit 1
fi

# Extract zone ingress names using jq
# Assuming the response is a JSON array or object with items
if [ -n "$ZONE_FILTER" ]; then
    # Filter by zone
    ZI_NAMES=$(echo "$RESPONSE" | jq -r --arg zone "$ZONE_FILTER" '.items[]? | select(.zone == $zone) | .name // empty')
else
    # No zone filter
    ZI_NAMES=$(echo "$RESPONSE" | jq -r '.items[]?.name // .[]?.name // empty')
fi

# If jq is not available, display error
if [ $? -ne 0 ]; then
    echo "Error: jq is required but not installed. Please install jq to parse JSON."
    echo "Raw response saved to ${OUTPUT_DIR}/raw_response.json"
    echo "$RESPONSE" > "${OUTPUT_DIR}/raw_response.json"
    exit 1
fi

# Check if any zone ingresses were found
if [ -z "$ZI_NAMES" ]; then
    if [ -n "$ZONE_FILTER" ]; then
        echo "No zone ingresses found for zone: $ZONE_FILTER"
    else
        echo "No zone ingresses found or unexpected response format"
    fi
    echo "Response saved to ${OUTPUT_DIR}/raw_response.json"
    echo "$RESPONSE" > "${OUTPUT_DIR}/raw_response.json"
    exit 1
fi

if [ -n "$ZONE_FILTER" ]; then
    echo "Found zone ingresses in zone '$ZONE_FILTER':"
else
    echo "Found zone ingresses:"
fi
echo "$ZI_NAMES"
echo ""

# Iterate through each zone ingress name
while IFS= read -r name; do
    if [ -n "$name" ]; then
        echo "Fetching data for zone ingress: $name"

        # Create directory for this zone ingress
        ZI_DIR="${OUTPUT_DIR}/${name}"
        mkdir -p "$ZI_DIR"

        # Fetch zone ingress resource
        ZI_URL="${KONNECT_API_URL}/zoneingresses/${name}"
        ZI_FILE="${ZI_DIR}/zone-ingress.json"

        echo "  Fetching zone-ingress..."
        curl -s -H "Authorization: Bearer ${KONNECT_TOKEN}" \
            "$ZI_URL" -o "$ZI_FILE"

        if [ $? -eq 0 ]; then
            echo "    ✓ Saved to: $ZI_FILE"
        else
            echo "    ✗ Failed to fetch zone-ingress"
        fi

        # Fetch XDS configuration (config_dump)
        XDS_URL="${KONNECT_API_URL}/zoneingresses/${name}/xds"
        CONFIG_DUMP_FILE="${ZI_DIR}/config_dump.json"

        echo "  Fetching config_dump..."
        curl -s -H "Authorization: Bearer ${KONNECT_TOKEN}" \
            "$XDS_URL" -o "$CONFIG_DUMP_FILE"

        if [ $? -eq 0 ]; then
            echo "    ✓ Saved to: $CONFIG_DUMP_FILE"
        else
            echo "    ✗ Failed to fetch config_dump"
        fi

        # Fetch clusters
        CLUSTERS_URL="${KONNECT_API_URL}/zoneingresses/${name}/clusters"
        CLUSTERS_FILE="${ZI_DIR}/clusters"

        echo "  Fetching clusters..."
        curl -s -H "Authorization: Bearer ${KONNECT_TOKEN}" \
            "$CLUSTERS_URL" -o "$CLUSTERS_FILE"

        if [ $? -eq 0 ]; then
            echo "    ✓ Saved to: $CLUSTERS_FILE"
        else
            echo "    ✗ Failed to fetch clusters"
        fi

        # Fetch stats
        STATS_URL="${KONNECT_API_URL}/zoneingresses/${name}/stats"
        STATS_FILE="${ZI_DIR}/stats"

        echo "  Fetching stats..."
        curl -s -H "Authorization: Bearer ${KONNECT_TOKEN}" \
            "$STATS_URL" -o "$STATS_FILE"

        if [ $? -eq 0 ]; then
            echo "    ✓ Saved to: $STATS_FILE"
        else
            echo "    ✗ Failed to fetch stats"
        fi

        echo ""
    fi
done <<< "$ZI_NAMES"

echo "Done! All zone ingress data saved to ${OUTPUT_DIR}/"
