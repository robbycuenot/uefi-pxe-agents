#!/bin/bash

# Check if the script is running as root
if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Check if the persistent handle exists by listing all persistent handles and searching for 0x8101FFFF
if ! tpm2_getcap handles-persistent | grep -q "0x8101FFFF"; then
    echo "Persistent handle 0x8101FFFF does not exist. Please set up the encryption key first."
    exit 1
fi

# Read base64-encoded string from stdin and decode it
echo "Enter the base64-encoded string to decrypt:"
read -r encrypted_base64
echo "$encrypted_base64" | base64 --decode > encrypted.bin

# Decrypt the string using the private part of the RSA key at persistent handle 0x8101FFFF
# -c 0x8101FFFF: Specifies the context (handle in this case) of the RSA key to use for decryption
# -o plaintext.txt: Output file for the decrypted data
# encrypted.bin: Input file containing the encrypted data
tpm2_rsadecrypt -c 0x8101FFFF -o plaintext.txt encrypted.bin

# Output the decrypted string to the console
echo "Decrypted string:"
cat plaintext.txt
