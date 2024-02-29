#!/bin/bash

# Check if the script is running as root
if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Check if the persistent handle 0x8101FFFF exists
if ! tpm2_getcap handles-persistent | grep -q "0x8101FFFF"; then
    echo "Creating persistent handle 0x8101FFFF..."

    # Create a primary key in the TPM's storage hierarchy (owner hierarchy)
    tpm2_createprimary -C o -c primary.ctx
    
    # Create an RSA key pair under the primary key
    tpm2_create -C primary.ctx -G rsa2048 -u rsa.pub -r rsa.priv
    
    # Load the RSA key pair into the TPM
    tpm2_load -C primary.ctx -u rsa.pub -r rsa.priv -c rsa.ctx
    
    # Make the RSA key persistent at handle 0x8101FFFF
    tpm2_evictcontrol -C o -c rsa.ctx 0x8101FFFF

    echo "Persistent handle 0x8101FFFF created successfully."
else
    echo "Persistent handle 0x8101FFFF already exists."
fi
