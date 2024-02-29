#!/bin/bash

# Path to the modified decryption script
decrypt_script="/var/home/systemUser/unattended_decryption.sh"

# Execute the decryption script and capture the output
decrypted_token=$($decrypt_script "/var/home/systemUser/encrypted_tfcagent_token.txt")

# Run the TFC agent with the decrypted token
podman run                                \
    -it                                   \
    --rm                                  \
    --replace                             \
    --name tfcagent                       \
    -e TFC_AGENT_TOKEN="$decrypted_token" \
    -e TFC_AGENT_NAME=local_agent         \
    docker.io/hashicorp/tfc-agent:latest