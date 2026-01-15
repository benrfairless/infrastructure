#!/bin/bash
# 1Password vault password fetcher for Ansible
# This script retrieves Ansible vault passwords from 1Password using the 1Password CLI
#
# Usage: op-vault-pass.sh <vault-id>
#   vault-id: The name of the vault password to retrieve (default, rtk, ec2, all)
#
# Prerequisites:
# - Install 1Password CLI: https://developer.1password.com/docs/cli/get-started/
# - Authenticate with: eval $(op signin)
# - Store vault passwords in 1Password with the reference format:
#   - "ansible-vault-default" for default vault
#   - "ansible-vault-rtk" for RTK vault
#   - "ansible-vault-ec2" for EC2 vault
#   - "ansible-vault-all" for All vault

set -euo pipefail

# Get the vault ID from the first argument, or use "default" if not provided
VAULT_ID="${1:-default}"

# Map vault IDs to 1Password item names
case "$VAULT_ID" in
  "default")
    ITEM_NAME="ansible-vault-default"
    ;;
  "rtk")
    ITEM_NAME="ansible-vault-rtk"
    ;;
  "ec2")
    ITEM_NAME="ansible-vault-ec2"
    ;;
  "all")
    ITEM_NAME="ansible-vault-all"
    ;;
  *)
    echo "Unknown vault ID: $VAULT_ID" >&2
    exit 1
    ;;
esac

# Fetch the password from 1Password
# Assumes passwords are stored in the "Infrastructure" vault
# Adjust the vault name as needed for your organization
op read "op://Infrastructure/$ITEM_NAME/password" 2>/dev/null || {
  echo "Failed to retrieve vault password for '$VAULT_ID' from 1Password." >&2
  echo "Make sure you're authenticated with 'eval \$(op signin)'" >&2
  echo "and that the item '$ITEM_NAME' exists in the 'Infrastructure' vault." >&2
  exit 1
}
