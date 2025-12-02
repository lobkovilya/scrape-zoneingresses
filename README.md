# Zone Ingress Data Fetcher

Fetches zone ingress data from Konnect API and saves configuration files.

## Requirements

- `jq` - JSON parser
- `curl` - HTTP client

## Usage

```bash
# Set environment variables
export KONNECT_TOKEN="your-token"
export KONNECT_API_URL="https://us.api.konghq.com/v1/mesh/control-planes/$cpId"

# Fetch all zone ingresses
./scrape.sh

# Fetch only zone ingresses in specific zone
./scrape.sh --zone "us-west-1"
```

## Output

Creates `zoneingress_xds_output/` directory with subdirectories for each zone ingress containing:
- `zone-ingress.json` - Zone ingress resource
- `config_dump.json` - XDS configuration
- `clusters` - Cluster data
- `stats` - Statistics
