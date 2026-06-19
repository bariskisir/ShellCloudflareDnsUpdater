# DNS Updater for Cloudflare

This project provides a simple Dockerized solution to automatically update Cloudflare DNS records with a device's public IP addresses. It supports IPv4 `A` records, IPv6 `AAAA` records, or both record types together.

The requested DNS records must already exist in Cloudflare. The updater checks them at the configured interval and updates their values when the public IP addresses change.

## Prerequisites

- Docker installed on your machine.
- A Cloudflare account with the DNS records you wish to update.
- A valid Cloudflare API token with permission to edit DNS records.
- Public IPv4 and/or IPv6 connectivity, depending on the selected mode.

## Environment Variables

- `CF_API_TOKEN`: Your Cloudflare API token. Create an `All zones - DNS:Edit` token in Cloudflare. [How to create API tokens](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
- `DNS_RECORD_NAME`: The DNS record name to update, for example `test.example.com`.
- `CHECK_INTERVAL_MINUTES`: How often public IP addresses are checked. Defaults to `10`.
- `IP_VERSION`: Selects which IP versions and DNS record types are updated. Defaults to `4`.
  - `4`: Update only the IPv4 `A` record.
  - `6`: Update only the IPv6 `AAAA` record.
  - `4,6`: Update both the IPv4 `A` and IPv6 `AAAA` records.

## Build the Docker Image

```bash
git clone https://github.com/bariskisir/ShellCloudflareDnsUpdater
cd ShellCloudflareDnsUpdater
docker build -t shellcloudflarednsupdater .
```

## Usage Examples

### IPv4 only

Updates only the `A` record. `IP_VERSION=4` is optional because IPv4 is the default.

```bash
docker run -d \
  --name shellcloudflarednsupdater \
  -e CF_API_TOKEN="your_cloudflare_api_token" \
  -e DNS_RECORD_NAME="test.example.com" \
  -e CHECK_INTERVAL_MINUTES="10" \
  -e IP_VERSION="4" \
  --restart unless-stopped \
  bariskisir/shellcloudflarednsupdater
```

### IPv6 only

Updates only the `AAAA` record.

```bash
docker run -d \
  --name shellcloudflarednsupdater \
  --network host \
  -e CF_API_TOKEN="your_cloudflare_api_token" \
  -e DNS_RECORD_NAME="test.example.com" \
  -e CHECK_INTERVAL_MINUTES="10" \
  -e IP_VERSION="6" \
  --restart unless-stopped \
  bariskisir/shellcloudflarednsupdater
```

### IPv4 and IPv6

Updates both the `A` and `AAAA` records for the same DNS name.

```bash
docker run -d \
  --name shellcloudflarednsupdater \
  --network host \
  -e CF_API_TOKEN="your_cloudflare_api_token" \
  -e DNS_RECORD_NAME="test.example.com" \
  -e CHECK_INTERVAL_MINUTES="10" \
  -e IP_VERSION="4,6" \
  --restart unless-stopped \
  bariskisir/shellcloudflarednsupdater
```

## Script Overview

The `update_dns.sh` script:

1. Retrieves the requested public IPv4 and/or IPv6 address.
2. Fetches the DNS zones associated with the Cloudflare account.
3. Finds the matching `A` and/or `AAAA` record.
4. Compares each record with the corresponding public IP address.
5. Updates records whose IP addresses have changed.
6. Repeats the process at the configured interval.

If both IP versions are enabled but one is unavailable, the updater skips that record type and continues processing the other one.

## License

This project is licensed under the MIT License. See the LICENSE file for more information.

[Docker Hub](https://hub.docker.com/r/bariskisir/shellcloudflarednsupdater)
