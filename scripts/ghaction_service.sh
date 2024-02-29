#!/bin/bash

# Path to the modified decryption script
decrypt_script="/var/home/systemUser/unattended_decryption.sh"

# Execute the decryption script and capture the output
decrypted_token=$($decrypt_script "/var/home/systemUser/encrypted_ghaction_token.txt")

# Run the TFC agent with the decrypted token
podman run                                   \
    -it                                      \
    --rm                                     \
    --replace                                \
    --name gh-runner-ubuntu                  \
    -e RUNNER_NAME=gh-runner-ubuntu          \
    -e RUNNER_TOKEN="$decrypted_token"       \
    -e REPO_URL=https://github.com/cuenot-io \
    -e RUNNER_WORKDIR=_work                  \
    docker.io/robbycuenot/gh-runner-ubuntu:latest