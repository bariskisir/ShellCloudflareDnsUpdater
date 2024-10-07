#!/bin/sh

# Cloudflare API Token (must have permissions to edit DNS records)
CF_API_TOKEN="${CF_API_TOKEN}"
DNS_RECORD_NAME="${DNS_RECORD_NAME}"
CHECK_INTERVAL_MINUTES="${CHECK_INTERVAL_MINUTES:-10}"  # Default to 10 minutes if not specified

# Convert minutes to seconds
CHECK_INTERVAL_SECONDS=$((CHECK_INTERVAL_MINUTES * 60))

# Function to get the public IP address of the Raspberry Pi
get_public_ip() {
    curl -s https://checkip.amazonaws.com
}

# Function to get all zones in the Cloudflare account
get_zones() {
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json"
}

# Function to get DNS records for a specific zone
get_dns_records() {
    local zone_id="$1"
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json"
}

# Function to get the current IP address of the DNS A record
get_current_record_ip() {
    local zone_id="$1"
    local record_name="$2"
    
    # Get all DNS records for the zone
    records=$(get_dns_records "${zone_id}")
    
    # Filter A record by name
    echo "${records}" | jq -r ".result[] | select(.type == \"A\" and .name == \"${record_name}\") | .content"
}

# Function to get the ID of an A record by name
get_record_id_by_name() {
    local zone_id="$1"
    local record_name="$2"
    
    # Get all DNS records for the zone
    records=$(get_dns_records "${zone_id}")
    
    # Find the record ID of the A record
    echo "${records}" | jq -r ".result[] | select(.type == \"A\" and .name == \"${record_name}\") | .id"
}

# Function to update the A record to the new IP address
update_dns_record() {
    local zone_id="$1"
    local record_id="$2"
    local new_ip="$3"
    
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data '{"type":"A","name":"'"${DNS_RECORD_NAME}"'","content":"'"${new_ip}"'","ttl":1,"proxied":false}'
}

# Main script logic
main() {
    echo "Fetching all zones..."
    zones=$(get_zones)
    
    # Loop over all zones to find the specified DNS record
    zone_id=""
    for zone in $(echo "${zones}" | jq -r '.result[] | @base64'); do
        _jq() {
            echo ${zone} | base64 -d | jq -r ${1}
        }

        # Get the zone name
        current_zone_name=$(_jq '.name')
        zone_id=$(_jq '.id')
        
        echo "Checking zone: ${current_zone_name}..."

        # Fetch all DNS records for the current zone
        records=$(get_dns_records "${zone_id}")
        
        # Look for the DNS record in this zone
        record_id=$(echo "${records}" | jq -r ".result[] | select(.type == \"A\" and .name == \"${DNS_RECORD_NAME}\") | .id")
        
        if [ ! -z "${record_id}" ]; then
            echo "Found A record in zone ${current_zone_name}."
            
            # Get the current IP of the existing A record
            current_ip=$(get_current_record_ip "${zone_id}" "${DNS_RECORD_NAME}")
            public_ip=$(get_public_ip)
            
            if [ "$current_ip" != "$public_ip" ]; then
                echo "IP address has changed. Updating A record from ${current_ip} to ${public_ip}..."
                
                # Update the DNS A record with the new IP
                update_dns_record "${zone_id}" "${record_id}" "${public_ip}"
                echo "A record updated successfully."
            else
                echo "IP address is the same. No update needed."
            fi
            
            # Exit the loop and continue checking after the interval
            echo "Waiting ${CHECK_INTERVAL_MINUTES} minutes before the next check..."
            return 0
        fi
    done

    # If the record wasn't found in any zone, print a message
    echo "A record ${DNS_RECORD_NAME} not found in any zone."
}

# Infinite loop to periodically check DNS record every X minutes
while true; do
    main
    echo "Waiting for ${CHECK_INTERVAL_MINUTES} minute(s) before the next check..."
    sleep ${CHECK_INTERVAL_SECONDS}  # Wait for the specified interval
done
