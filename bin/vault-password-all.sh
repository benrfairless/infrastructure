#!/usr/bin/env bash
# Vault password script for the all vault identity.
# Reads the password from the environment variable set by `fnox exec --`.
echo "$ANSIBLE_VAULT_PASSWORD_ALL"
