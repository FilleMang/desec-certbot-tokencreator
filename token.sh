#!/bin/bash

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
  echo "jq could not be found. Please install jq and try again."
  exit 1
fi

# Ensure curl is installed
if ! command -v curl &> /dev/null; then
  echo "curl could not be found. Please install curl and try again."
  exit 1
fi

# Prompt the user for the admin token
echo "Create your account and admin token at https://desec.io/"
echo "Don't forget to grant permission for token management. This setting is located under advanced settings."
read -p "Enter the admin token: " ADMINNYCKEL

# Check if the admin token is provided
if [ -z "$ADMINNYCKEL" ]; then
  echo "Admin token cannot be empty."
  exit 1
fi

# Make the curl request to create a new token
response=$(curl -X POST https://desec.io/api/v1/auth/tokens/ \
  --header "Authorization: Token $ADMINNYCKEL" \
  --header "Content-Type: application/json" \
  --data @- <<< '{"name": "Certbot-token"}')

# Check if the curl request was successful
if [ $? -ne 0 ]; then
  echo "Failed to make the API request."
  exit 1
fi

# Parse the JSON response using jq
echo "API Response:"
echo "$response" | jq .

# Check if the response contains an error message
if echo "$response" | jq -e '.detail' > /dev/null; then
  echo "Invalid admin token. Please check your token and try again."
  exit 1
fi

# Extract the id and token values
ID=$(echo "$response" | jq -r '.id')
TOKEN=$(echo "$response" | jq -r '.token')

# Check if the extraction was successful
if [ -z "$ID" ] || [ -z "$TOKEN" ]; then
  echo "Failed to extract id or token from the response."
  exit 1
fi

# Parse the JSON response using jq
echo "API Response:"
echo "$response" | jq .

# Extract the id and token values
ID=$(echo "$response" | jq -r '.id')
TOKEN=$(echo "$response" | jq -r '.token')

# Check if the extraction was successful
if [ -z "$ID" ] || [ -z "$TOKEN" ]; then
  echo "Failed to extract id or token from the response."
  exit 1
fi

# Export the id and token as environment variables
export ID
export TOKEN

# Create a new profile with no permissions
echo "Creating a new profile with no permissions..."
response_no_permissions=$(curl -X POST https://desec.io/api/v1/auth/tokens/$ID/policies/rrsets/ \
  --header "Authorization: Token $ADMINNYCKEL" \
  --header "Content-Type: application/json" \
  --data @- <<< '{"domain": null, "subname": null, "type": null}')

echo "Empty profile created."
echo "API Response for empty profile:"
echo "$response_no_permissions" | jq .

# Prompt the user for the domain name
read -p "Enter the domain name for the new key: " DOMANNAMN

# Check if the domain name is provided
if [ -z "$DOMANNAMN" ]; then
  echo "Domain name cannot be empty."
  exit 1
fi

# Check if the domain exists and is linked to the account
response=$(curl -X GET https://desec.io/api/v1/domains/$DOMANNAMN/ \
  --header "Authorization: Token $ADMINNYCKEL" \
  --silent --fail)

if [ $? -ne 0 ]; then
  echo "The domain $DOMANNAMN does not exist or is not linked to your account."
  echo "Please add the domain to deSEC and try again."
  exit 1
fi

# Om domänen existerar och är kopplad till kontot, fortsätt med skriptet
echo "Creating a new profile with permissions for the domain $DOMANNAMN..."
response_with_permissions=$(curl -X POST https://desec.io/api/v1/auth/tokens/$ID/policies/rrsets/ \
  --header "Authorization: Token $ADMINNYCKEL" \
  --header "Content-Type: application/json" \
  --data @- <<< "{\"domain\": \"$DOMANNAMN\", \"subname\": \"_acme-challenge\", \"type\": \"TXT\", \"perm_write\": true}")

echo "New profile with permissions created for the domain $DOMANNAMN."
echo "API Response for new profile with permissions:"
echo "$response_with_permissions" | jq .

# List all permissions for the new token
echo "Listing all permissions for the new token..."
permissions_response=$(curl -X GET https://desec.io/api/v1/auth/tokens/$ID/policies/rrsets/ \
  --header "Authorization: Token $ADMINNYCKEL")

echo "Permissions for the new token:"
echo "$permissions_response" | jq .

# Create the configuration file
CONFIG_FILE="$DOMANNAMN.ini"
echo "dns_desec_token = $TOKEN" > "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

# Provide instructions to the user
echo "Configuration file created: $CONFIG_FILE"
echo "Please move this file to /etc/letsencrypt/secrets/ and rename it to $DOMANNAMN.ini"
echo "You can then run the following command to obtain a certificate:"
echo "certbot certonly --authenticator dns-desec --dns-desec-credentials /etc/letsencrypt/secrets/$DOMANNAMN.ini -d \"$DOMANNAMN\" -d \"*.$DOMANNAMN\""
echo "Information regarding the desec plugin can be found at https://github.com/desec-io/certbot-dns-desec?tab=readme-ov-file#installation"

echo "Additionally, you can set up a cron job to renew the certificate automatically. Edit the sudo crontab with the following command:"
echo "sudo crontab -e"
echo "Add and edit the following line to the crontab file to renew the certificate daily at 2 AM:"
echo "0 2 * * * ENTER YOUR PATH TO CERTBOT HERE!/certbot renew --quiet --authenticator dns-desec --dns-desec-credentials /etc/letsencrypt/secrets/$DOMANNAMN.ini -d \"$DOMANNAMN\" -d \"*.$DOMANNAMN\" --posthook \"systemctl reload nginx\""
echo "This will ensure that your certificate is renewed automatically and your web server is reloaded to use the new certificate."
