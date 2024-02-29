#!/bin/bash

# Check if the script is running as root
if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Check if the persistent handle exists
if ! tpm2_getcap handles-persistent | grep -q "0x8101FFFF"; then
    echo "Persistent handle 0x8101FFFF does not exist. Please set up the encryption key first."
    exit 1
fi

# Prompt for a string to encrypt
echo "Enter a string to encrypt:"
read -r data_to_encrypt

# Convert input to a file
echo -n "$data_to_encrypt" > plaintext.txt

# Encrypt the string using the RSA key at persistent handle 0x8101FFFF
tpm2_rsaencrypt -c 0x8101FFFF -o ciphertext.bin plaintext.txt

# Base64 encode the encrypted string and output it to the console
base64 ciphertext.bin | tr -d '\n'
echo # Add a newline for cleanliness

echo "Encryption complete."
