#!/usr/bin/env bash
# Vault password script for the rtk vault identity.
# Reads the password from the environment variable set by `fnox exec --`.
echo "$ANSIBLE_VAULT_PASSWORD_RTK"
