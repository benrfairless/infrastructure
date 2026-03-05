#!/usr/bin/env bash
# Vault password script for the ec2 vault identity.
# Reads the password from the environment variable set by `fnox exec --`.
echo "$ANSIBLE_VAULT_PASSWORD_EC2"
