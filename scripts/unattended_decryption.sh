#!/bin/bash

# Check if an argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <encrypted_token_file_path>"
    exit 1
fi

# The first command line argument is the path to the encrypted token file
encrypted_token_file="$1"

# Check if the script is running as root
if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Check if the persistent handle exists
if ! tpm2_getcap handles-persistent | grep -q "0x8101FFFF"; then
    echo "Persistent handle 0x8101FFFF does not exist. Please set up the encryption key first." >&2
    exit 1
fi

# Check if the encrypted token file exists
if [ ! -f "$encrypted_token_file" ]; then
    echo "Encrypted token file ($encrypted_token_file) not found." >&2
    exit 1
fi

# Decrypt the string using the RSA key at persistent handle 0x8101FFFF
# and capture the output directly without writing to a file
decrypted_token=$(base64 --decode < "$encrypted_token_file" | tpm2_rsadecrypt -c 0x8101FFFF)

# Output the decrypted token (for debugging purposes, might want to remove in production)
echo "$decrypted_token"

# The script will end here, and $decrypted_token contains the decrypted value
