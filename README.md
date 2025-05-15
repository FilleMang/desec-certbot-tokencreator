# deSEC Certbot Token Creator

This script automates the creation of a deSEC token with restricted privileges to administer `_acme-challenge` entries. It is designed to facilitate the creation of DNS records necessary for ACME challenges, such as those used by Let's Encrypt for certificate issuance.

It will create a token and a file for you to use with the certbot-plugin from desec: https://github.com/desec-io/certbot-dns-desec


## Prerequisites

Before running this script, ensure you have the following installed:

- `curl`: A command-line tool for transferring data using various network protocols.
- `jq`: A lightweight and flexible command-line JSON processor.

./token.sh
