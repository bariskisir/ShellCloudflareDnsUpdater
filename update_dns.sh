#!/bin/sh

# Cloudflare API Token (must have permissions to edit DNS records)
CF_API_TOKEN="${CF_API_TOKEN}"
DNS_RECORD_NAME="${DNS_RECORD_NAME}"
CHECK_INTERVAL_MINUTES="${CHECK_INTERVAL_MINUTES:-10}"
IP_VERSION="${IP_VERSION:-4}"

# Convert minutes to seconds
CHECK_INTERVAL_SECONDS=$((CHECK_INTERVAL_MINUTES * 60))

validate_configuration() {
    if [ -z "${CF_API_TOKEN}" ] || [ -z "${DNS_RECORD_NAME}" ]; then
        echo "CF_API_TOKEN and DNS_RECORD_NAME environment variables are required."
        exit 1
    fi

    case "${IP_VERSION}" in
        4|6|4,6|6,4)
            ;;
        *)
            echo "Invalid IP_VERSION value: ${IP_VERSION}. Supported values are 4, 6, and 4,6."
            exit 1
            ;;
    esac
}

# Get the public IP address for the requested IP version.
get_public_ip() {
    local ip_version="$1"

    if [ "${ip_version}" = "4" ]; then
        curl -4 -fsS https://api.ipify.org
    else
        curl -6 -fsS https://api6.ipify.org
    fi
}

# Get all zones in the Cloudflare account.
get_zones() {
    curl -fsS -X GET "https://api.cloudflare.com/client/v4/zones" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json"
}

# Get DNS records for a specific zone.
get_dns_records() {
    local zone_id="$1"

    curl -fsS -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json"
}

# Update an A or AAAA record to the new IP address.
update_dns_record() {
    local zone_id="$1"
    local record_id="$2"
    local record_type="$3"
    local new_ip="$4"

    curl -fsS -X PUT "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data '{"type":"'"${record_type}"'","name":"'"${DNS_RECORD_NAME}"'","content":"'"${new_ip}"'","ttl":1,"proxied":false}'
}

record_type_for_ip_version() {
    if [ "$1" = "4" ]; then
        echo "A"
    else
        echo "AAAA"
    fi
}

# Find and update the DNS record for one IP version.
update_ip_version() {
    local ip_version="$1"
    local zones="$2"
    local record_type
    local public_ip
    local update_response

    record_type=$(record_type_for_ip_version "${ip_version}")

    if ! public_ip=$(get_public_ip "${ip_version}"); then
        echo "Could not retrieve the public IPv${ip_version} address. Skipping ${record_type} record."
        return 1
    fi

    if [ -z "${public_ip}" ]; then
        echo "Public IPv${ip_version} address is empty. Skipping ${record_type} record."
        return 1
    fi

    echo "Public IPv${ip_version} address: ${public_ip}"

    for encoded_zone in $(echo "${zones}" | jq -r '.result[] | @base64'); do
        zone=$(echo "${encoded_zone}" | base64 -d)
        current_zone_name=$(echo "${zone}" | jq -r '.name')
        zone_id=$(echo "${zone}" | jq -r '.id')

        echo "Checking ${record_type} record in zone: ${current_zone_name}..."

        if ! records=$(get_dns_records "${zone_id}"); then
            echo "Could not retrieve DNS records for zone ${current_zone_name}."
            continue
        fi

        record=$(echo "${records}" | jq -c \
            --arg type "${record_type}" \
            --arg name "${DNS_RECORD_NAME}" \
            '.result[] | select(.type == $type and .name == $name)' | head -n 1)

        if [ -z "${record}" ]; then
            continue
        fi

        record_id=$(echo "${record}" | jq -r '.id')
        current_ip=$(echo "${record}" | jq -r '.content')

        if [ "${current_ip}" = "${public_ip}" ]; then
            echo "${record_type} record already has the current IPv${ip_version} address. No update needed."
            return 0
        fi

        echo "IPv${ip_version} address has changed. Updating ${record_type} record from ${current_ip} to ${public_ip}..."

        if update_response=$(update_dns_record "${zone_id}" "${record_id}" "${record_type}" "${public_ip}") &&
            echo "${update_response}" | jq -e '.success == true' > /dev/null; then
            echo "${record_type} record updated successfully."
        else
            echo "Failed to update ${record_type} record."
            return 1
        fi

        return 0
    done

    echo "${record_type} record ${DNS_RECORD_NAME} not found in any zone."
    return 1
}

main() {
    echo "Fetching all zones..."

    if ! zones=$(get_zones); then
        echo "Could not retrieve Cloudflare zones."
        return 1
    fi

    case "${IP_VERSION}" in
        4)
            update_ip_version "4" "${zones}"
            ;;
        6)
            update_ip_version "6" "${zones}"
            ;;
        4,6|6,4)
            update_ip_version "4" "${zones}"
            update_ip_version "6" "${zones}"
            ;;
    esac
}

validate_configuration

# Periodically check DNS records.
while true; do
    main
    echo "Waiting for ${CHECK_INTERVAL_MINUTES} minute(s) before the next check..."
    sleep "${CHECK_INTERVAL_SECONDS}"
done
