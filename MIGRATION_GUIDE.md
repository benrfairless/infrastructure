# Infrastructure Modernization Migration Guide

This guide helps you transition from the old infrastructure setup to the modernized version.

## Overview of Changes

This repository has been modernized with the following changes:

1. **Python**: 3.11.13 → 3.13.1
2. **Ruby**: 2.7.6 → 3.3.6
3. **Ansible**: 2.10.7 → 10.x (with ansible-core 2.17.x)
4. **Terraform → OpenTofu**: Migrated to open-source OpenTofu
5. **Mise**: Added for tool version management
6. **1Password**: Replaced Keybase for secrets management

## Prerequisites

### 1. Install Mise

Mise is a modern tool version manager that replaces asdf, rbenv, pyenv, etc.

```bash
# Install mise (macOS)
brew install mise

# Install mise (Linux)
curl https://mise.run | sh

# Activate mise in your shell
echo 'eval "$(mise activate bash)"' >> ~/.bashrc  # For bash
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc   # For zsh

# Reload your shell
source ~/.bashrc  # or source ~/.zshrc
```

### 2. Install Tools via Mise

Navigate to the infrastructure directory and let mise install the required tools:

```bash
cd /path/to/infrastructure
mise install  # Installs Python 3.13.1, Ruby 3.3.6, and OpenTofu 1.9.0
```

Mise will automatically use the correct versions when you're in this directory.

### 3. Install 1Password CLI

1Password CLI is required for managing Ansible vault passwords.

```bash
# macOS
brew install --cask 1password-cli

# Linux (Debian/Ubuntu)
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update && sudo apt install 1password-cli
```

### 4. Authenticate with 1Password

```bash
# Sign in to your 1Password account
eval $(op signin)

# Verify authentication
op account list
```

## Migrating from Keybase to 1Password

### Step 1: Export Vault Passwords from Keybase

Before removing Keybase, you need to migrate your vault passwords to 1Password.

```bash
# Read the existing vault passwords from Keybase
cat .vault_pass.txt
cat .rtk-vault-pass
cat .ec2-vault-pass
cat .all-vault-pass
```

### Step 2: Store Vault Passwords in 1Password

Create a new vault in 1Password called "Infrastructure" (or use an existing vault), then store each vault password:

```bash
# Create items in 1Password for each vault password
# Use the 1Password web interface or CLI to create these items:

# For default vault:
op item create --category=password --title="ansible-vault-default" \
  --vault="Infrastructure" password="<paste-password-here>"

# For RTK vault:
op item create --category=password --title="ansible-vault-rtk" \
  --vault="Infrastructure" password="<paste-password-here>"

# For EC2 vault:
op item create --category=password --title="ansible-vault-ec2" \
  --vault="Infrastructure" password="<paste-password-here>"

# For All vault:
op item create --category=password --title="ansible-vault-all" \
  --vault="Infrastructure" password="<paste-password-here>"
```

**Important**: Update the vault name in `bin/op-vault-pass.sh` if you use a different vault name than "Infrastructure".

### Step 3: Test 1Password Integration

Before removing Keybase symlinks, test that the 1Password integration works:

```bash
# Test the script
./bin/op-vault-pass.sh default
./bin/op-vault-pass.sh rtk
./bin/op-vault-pass.sh ec2
./bin/op-vault-pass.sh all

# Test with Ansible
.venv/bin/ansible-vault view group_vars/ec2.yml
```

### Step 4: Remove Keybase Symlinks

Once you've verified that 1Password works correctly, remove the old Keybase symlinks:

```bash
# Remove Keybase vault password symlinks
rm -f .vault_pass.txt .rtk-vault-pass .ec2-vault-pass .all-vault-pass

# Remove Keybase directory symlink
rm -f .keybase

# Remove Keybase terraform key (if you've migrated it to 1Password)
rm -f terraform.pem
```

### Step 5: Update Your Workflow

The new workflow no longer requires Keybase. Instead:

1. Authenticate with 1Password at the start of your session:
   ```bash
   eval $(op signin)
   ```

2. Run Ansible commands as usual:
   ```bash
   make production
   make check-planningalerts
   ```

The vault passwords will be automatically fetched from 1Password as needed.

## OpenTofu Migration

OpenTofu is a drop-in replacement for Terraform. No code changes are needed.

### Using OpenTofu

The Makefile now uses `tofu` instead of `terraform`:

```bash
# Initialize OpenTofu
make tf-init

# Plan changes
make tf-plan

# Apply changes
make tf-apply
```

If you have existing Terraform state, OpenTofu will read it without issues. The state format is compatible.

### Manual OpenTofu Commands

You can also use `tofu` directly (mise ensures it's available):

```bash
cd terraform
tofu init
tofu plan
tofu apply
```

## Ansible 10.x Updates

Ansible 10.x includes several improvements and deprecation removals:

### Key Changes

1. **Python 3 Only**: No more Python 2 support
2. **Modern AWS Modules**: Using `amazon.aws` collection with `rds_instance_info` instead of deprecated `rds` module
3. **Collections**: Updated to use latest collection versions

### Testing Your Roles

Before running on production, test your changes:

```bash
# Check mode (dry run) for specific services
make check-planningalerts
make check-righttoknow-staging

# Apply to staging first
make apply-righttoknow-staging

# Then production
make apply-righttoknow-prod
```

## Updated Development Workflow

### Daily Workflow

1. **Authenticate with 1Password** (once per session):
   ```bash
   eval $(op signin)
   ```

2. **Ensure you're in the infrastructure directory** (mise activates automatically):
   ```bash
   cd /path/to/infrastructure
   mise doctor  # Verify mise setup
   ```

3. **Set up Python virtual environment** (first time or after updates):
   ```bash
   make venv
   make roles
   ```

4. **Run Ansible playbooks**:
   ```bash
   make production
   # or for specific services
   make apply-planningalerts
   ```

5. **Run OpenTofu**:
   ```bash
   make tf-plan
   make tf-apply
   ```

### Helper Commands

```bash
# Check 1Password authentication
make check-1password

# Install/update Ansible roles
make roles

# Clean and rebuild
make clean-all
make venv
make roles
```

## Troubleshooting

### Mise Issues

**Problem**: Tools not found or wrong versions

```bash
# Verify mise installation
mise --version

# Check which tools are available
mise list

# Reinstall tools
mise install --force
```

### 1Password Issues

**Problem**: "Failed to retrieve vault password"

```bash
# Re-authenticate
eval $(op signin)

# Verify item exists
op item get "ansible-vault-default" --vault="Infrastructure"

# Check script permissions
chmod +x bin/op-vault-pass.sh
```

**Problem**: "Not authenticated with 1Password"

Your 1Password session may have expired. Run:
```bash
eval $(op signin)
```

### Ansible Issues

**Problem**: "Module not found" errors

```bash
# Reinstall collections
rm -rf collections
make collections
```

**Problem**: RDS module errors

The old `rds` module has been replaced with `amazon.aws.rds_instance_info`. If you see errors, ensure you have:
```bash
.venv/bin/ansible-galaxy collection install amazon.aws
```

### OpenTofu Issues

**Problem**: "command not found: tofu"

```bash
# Ensure mise is activated
mise doctor

# Reinstall OpenTofu
mise install opentofu@1.9.0
```

## Rollback Instructions

If you need to rollback to the old setup:

```bash
# Checkout the previous commit
git log --oneline  # Find the commit before modernization
git checkout <commit-hash>

# Reinstall old dependencies
make clean-all
make venv
make roles
```

## Getting Help

- **Mise Documentation**: https://mise.jdx.dev/
- **1Password CLI Documentation**: https://developer.1password.com/docs/cli/
- **OpenTofu Documentation**: https://opentofu.org/docs/
- **Ansible 10.x Documentation**: https://docs.ansible.com/ansible/latest/

## Post-Migration Checklist

- [ ] Mise installed and activated
- [ ] Python 3.13.1, Ruby 3.3.6, and OpenTofu 1.9.0 installed via mise
- [ ] 1Password CLI installed
- [ ] Authenticated with 1Password (`eval $(op signin)`)
- [ ] All vault passwords migrated to 1Password
- [ ] Tested vault password retrieval with `./bin/op-vault-pass.sh`
- [ ] Tested Ansible playbook in check mode
- [ ] Old Keybase symlinks removed
- [ ] OpenTofu initialized and tested
- [ ] Production deployments tested on staging first
