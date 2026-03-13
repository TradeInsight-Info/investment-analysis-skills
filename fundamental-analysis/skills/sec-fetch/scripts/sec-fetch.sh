#!/usr/bin/env bash
# Fetch data from SEC EDGAR with the required User-Agent header.
# SEC requires: "Name email@example.com" in the User-Agent.
#
# Usage: sec-fetch.sh <url> <name> <email>
# Example: sec-fetch.sh "https://www.sec.gov/files/company_tickers.json" "John Doe" "john@example.com"

set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: $0 <url> <name> <email>" >&2
  exit 1
fi

URL="$1"
NAME="$2"
EMAIL="$3"

curl -sf \
  -H "User-Agent: ${NAME} ${EMAIL}" \
  -H "Accept: application/json" \
  "$URL"
