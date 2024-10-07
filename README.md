# DNS Updater for Cloudflare

This project provides a simple Dockerized solution to automatically update a Cloudflare DNS A record to match the public IP address of a device. The updater checks the public IP at specified intervals and updates the DNS record if there is a change.

## Prerequisites

-   Docker installed on your machine.
-   A Cloudflare account with API access and a DNS record you wish to update.
-   A valid API token from Cloudflare with permissions to edit DNS records.

## Environment Variables

Before running the Docker container, you need to set the following environment variables:

-   `CF_API_TOKEN`: Your Cloudflare API token. Create "All zones - DNS:Edit" token from cloudflare. [How to](https://support.cloudflare.com/hc/en-us/articles/200167836-Managing-API-Tokens-and-Keys#12345680)
-   `DNS_RECORD_NAME`: The name of the DNS A record you wish to update (e.g., `test.example.com`).
-   `CHECK_INTERVAL_MINUTES`: The interval (in minutes) at which the script checks the public IP address (default is 10 minutes).

## Usage

1.  **Build the Docker Image**
    
    Navigate to the directory containing the `Dockerfile` and run:
	```bash
	git clone https://github.com/bariskisir/ShellCloudflareDnsUpdater
	cd ShellCloudflareDnsUpdater
	docker build -t shellcloudflarednsupdater .
	```
    
2.  **Run the Docker Container**
    
    Use the following command to run the container, replacing the environment variable values as needed:
	```bash
	docker run -d \
        --name shellcloudflarednsupdater \
        -e CF_API_TOKEN="your_cloudflare_api_token" \
        -e DNS_RECORD_NAME="test.example.com" \
        -e CHECK_INTERVAL_MINUTES="10" \
        --restart unless-stopped \
        bariskisir/shellcloudflarednsupdater
	```
       
    This command will run the container in detached mode, checking and updating the DNS record as necessary.

## Script Overview

The `update_dns.sh` script performs the following tasks:

1.  Retrieves the public IP address of the device.
2.  Fetches all DNS zones associated with the Cloudflare account.
3.  Checks for the specified DNS A record in each zone.
4.  Compares the current IP address of the DNS record with the device's public IP address.
5.  Updates the DNS A record if there is a discrepancy.
6.  Repeats the process at the specified interval.

## License

This project is licensed under the MIT License. See the LICENSE file for more information.

[Dockerhub](https://hub.docker.com/r/bariskisir/shellcloudflarednsupdater)
