#!/bin/bash

# Path to the modified decryption script
decrypt_script="/var/home/systemUser/unattended_decryption.sh"

# Execute the decryption script and capture the output
decrypted_token=$($decrypt_script "/var/home/systemUser/encrypted_ghaction_token.txt")

organization=$(cat /var/home/systemUser/github_token_organization.txt)

REG_TOKEN=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $decrypted_token" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/orgs/$organization/actions/runners/registration-token \
  | jq .token --raw-output)

# Run the TFC agent with the decrypted token
podman run                                       \
    -it                                          \
    --rm                                         \
    --replace                                    \
    --name gh-runner-ubuntu                      \
    -e RUNNER_NAME=gh-runner-ubuntu              \
    -e RUNNER_TOKEN="$REG_TOKEN"                 \
    -e REPO_URL=https://github.com/$organization \
    -e RUNNER_WORKDIR=_work                      \
    docker.io/robbycuenot/gh-runner-ubuntu:latest