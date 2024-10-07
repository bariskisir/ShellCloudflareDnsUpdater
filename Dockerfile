# Use the latest Alpine base image
FROM alpine:latest

# Install dependencies: curl for API requests, jq for JSON processing
RUN apk add --no-cache curl jq

# Set environment variables (these will be passed when running the container)
ENV CF_API_TOKEN=""
ENV DNS_RECORD_NAME=""
ENV CHECK_INTERVAL_MINUTES="10"

# Copy the shell script into the Docker container
COPY update_dns.sh /usr/local/bin/update_dns.sh

# Make the script executable
RUN chmod +x /usr/local/bin/update_dns.sh

# Run the script
CMD ["/usr/local/bin/update_dns.sh"]
