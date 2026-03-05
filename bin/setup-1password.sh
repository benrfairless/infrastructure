#!/bin/sh
# Verify that the 1Password CLI is installed and signed in,
# then check that each Ansible vault password can be retrieved.
set -e

if ! command -v op >/dev/null 2>&1; then
    echo "Error: 1Password CLI ('op') is not installed."
    echo "Install it from https://developer.1password.com/docs/cli/get-started/"
    exit 1
fi

if ! op whoami >/dev/null 2>&1; then
    echo "You are not signed in to 1Password."
    echo "Run 'op signin' and try again."
    exit 1
fi

echo "Signed in as: $(op whoami --format=json | grep email | head -1)"
echo

echo "Checking vault passwords..."
FAILED=0

check_secret() {
    label="$1"
    ref="$2"
    if op read "$ref" >/dev/null 2>&1; then
        echo "  [OK]  $label"
    else
        echo "  [FAIL] $label  ($ref)"
        FAILED=1
    fi
}

check_secret "default vault pass"  "op://oaforgau-sysadmin/ansible-vault-pass/password"
check_secret "ec2 vault pass"      "op://oaforgau-sysadmin/ansible-ec2-vault-pass/password"
check_secret "all vault pass"      "op://oaforgau-sysadmin/ansible-all-vault-pass/password"
check_secret "rtk vault pass"      "op://oaforgau-righttoknow/ansible-rtk-vault-pass/password"

if [ "$FAILED" -eq 0 ]; then
    echo
    echo "All vault passwords are accessible. You are ready to run Ansible."
else
    echo
    echo "Some vault passwords could not be retrieved."
    echo "Make sure you are a member of the relevant 1Password vaults:"
    echo "  - oaforgau-sysadmin  (for default, ec2, all)"
    echo "  - oaforgau-righttoknow  (for rtk)"
    exit 1
fi
