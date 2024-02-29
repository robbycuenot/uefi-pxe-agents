#!/bin/bash

# Check if the script is running as root
if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Define the persistent handle you want to clear
persistent_handle="0x8101FFFF"

# Check if the persistent handle exists
if tpm2_getcap handles-persistent | grep -q "$persistent_handle"; then
    # The object exists at the persistent handle; remove it
    # -C o: Specifies the owner hierarchy (where the persistent handle is located)
    # -c: Specifies the object context, which is the persistent handle in this case
    tpm2_evictcontrol -C o -c $persistent_handle

    echo "TPM object at handle $persistent_handle has been removed."
else
    # The object does not exist at the persistent handle
    echo "No TPM object found at handle $persistent_handle. Nothing to remove."
fi
