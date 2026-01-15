# Compatibility Fixes for Ansible 10.x and OpenTofu 1.9.0

This document details the compatibility fixes applied to ensure the infrastructure repository works with modernized versions of Ansible and OpenTofu.

## Summary

**Date**: 2026-01-15
**Ansible Version**: 10.x (ansible-core 2.17.x)
**OpenTofu Version**: 1.9.0
**AWS Provider**: 5.82.0
**Cloudflare Provider**: 4.48.0

---

## Critical Fixes Applied

### Ansible Compatibility Fixes

#### 1. Deprecated Module Replacements

**apt_key and apt_repository modules (BREAKING)**

These modules were **removed** in Ansible 10.x and have been replaced with modern alternatives:

**Fixed Files:**
- `/home/user/infrastructure/roles/internal/postgresql/tasks/main.yml`
  - Replaced `apt_key` with `ansible.builtin.get_url` to download GPG key to `/usr/share/keyrings/`
  - Replaced `apt_repository` with `ansible.builtin.deb822_repository`
  - Uses `{{ ansible_distribution_release }}` for dynamic Ubuntu release support

- `/home/user/infrastructure/roles/internal/oaf.certbot/tasks/main.yml`
  - Removed deprecated PPA setup (certbot is available in Ubuntu 20.04+)
  - Removed Python 2 support
  - Simplified to use only `python3-certbot-*` packages

**Migration Pattern:**
```yaml
# OLD (Removed in Ansible 10.x)
- name: Import repository signing key
  apt_key:
    url: https://example.com/key.asc
    id: KEYID

- name: Add apt repository
  apt_repository:
    repo: deb http://example.com/repo jammy main
    filename: example

# NEW (Ansible 10.x compatible)
- name: Download repository signing key
  ansible.builtin.get_url:
    url: https://example.com/key.asc
    dest: /usr/share/keyrings/example-archive-keyring.asc
    mode: '0644'

- name: Add apt repository
  ansible.builtin.deb822_repository:
    name: example
    types: deb
    uris: http://example.com/repo
    suites: "{{ ansible_distribution_release }}"
    components: main
    signed_by: /usr/share/keyrings/example-archive-keyring.asc
    state: present
```

#### 2. Python 2 Package Removal

**Fixed Files:**
- `/home/user/infrastructure/roles/internal/mysql/tasks/main.yml`
  - Changed `python-mysqldb` → `python3-mysqldb`
  - Updated `update_cache: yes` → `update_cache: true`

**Impact:** All systems now require Python 3 only (Python 2 reached EOL in 2020).

#### 3. Deprecated Include Statements

**Fixed Files:**
- `/home/user/infrastructure/roles/internal/oaf.backup/tasks/main.yml`
- `/home/user/infrastructure/roles/internal/oaf.backup/tasks/backup.yml`

**Migration Pattern:**
```yaml
# OLD (Deprecated)
- include: backup.yml
  when: backup_enabled

# NEW
- name: Include backup tasks
  include_tasks: backup.yml
  when: backup_enabled
```

All `include:` statements have been replaced with `include_tasks:` with proper task names.

---

### Terraform/OpenTofu Compatibility Fixes

#### 1. Deprecated aws_eip Resource Arguments

**Fixed Files:**
- `/home/user/infrastructure/terraform/vpn-server.tf`

**Issue:** The `instance` argument in `aws_eip` is deprecated in AWS Provider 5.x.

**Migration Pattern:**
```hcl
# OLD (Deprecated in AWS Provider 5.x)
resource "aws_eip" "example" {
  instance = aws_instance.example.id
  tags = { Name = "example" }
}

# NEW
resource "aws_eip" "example" {
  domain = "vpc"
  tags = { Name = "example" }
}

resource "aws_eip_association" "example" {
  instance_id   = aws_instance.example.id
  allocation_id = aws_eip.example.id
}
```

#### 2. Deprecated aws_s3_bucket_acl Resource

**Fixed Files:**
- `/home/user/infrastructure/terraform/backend.tf`

**Issue:** `aws_s3_bucket_acl` is deprecated in AWS Provider 4.x+ and requires `aws_s3_bucket_ownership_controls`.

**Migration Pattern:**
```hcl
# NEW (Required first)
resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# THEN (With dependency)
resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.example.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.example]
}
```

#### 3. Missing MX Record Priorities

**Fixed Files:**
- `/home/user/infrastructure/terraform/raisely/dns.tf`

**Issue:** Cloudflare Provider 4.x requires `priority` field for MX records.

**Fix:**
```hcl
resource "cloudflare_record" "mx1" {
  zone_id  = var.zone_id
  name     = "donate.oaf.org.au"
  type     = "MX"
  priority = 10  # REQUIRED in provider 4.x
  value    = "mxa.mailgun.org"
}
```

#### 4. Provider Version Constraints

**Fixed Files:**
- `/home/user/infrastructure/terraform/versions.tf`
  - Updated `required_version` from `>= 1.6.0` → `>= 1.9.0`
  - Added `google` provider with version `~> 6.17.0`

- `/home/user/infrastructure/terraform/raisely/dns.tf`
  - Removed local provider version block to inherit from root

---

## Known Issues Requiring Follow-Up

### Ansible Issues

#### HIGH PRIORITY

**Remaining apt_key/apt_repository Usage:**

These roles still use deprecated modules and will **BREAK** with Ansible 10.x:

1. **metabase** (`roles/internal/metabase/tasks/main.yml:7,11`)
   - Docker repository setup uses `apt_key` and `apt_repository`

2. **openaustralia** (`roles/internal/openaustralia/tasks/main.yml:173,179`)
   - Node.js PPA setup uses `apt_repository`

3. **righttoknow** (`roles/internal/righttoknow/tasks/main.yml:12,15`)
   - Passenger PPA setup uses `apt_repository`

4. **theyvoteforyou** (`roles/internal/theyvoteforyou/tasks/main.yml:8,18,303,308`)
   - Multiple repository setups use `apt_key` and `apt_repository`

**Recommended Action:** Apply the same migration pattern used for postgresql and oaf.certbot roles.

#### MEDIUM PRIORITY

**Loop Syntax Deprecations:**

- **with_items**: Found in 10 roles with 100+ occurrences
  - Should be replaced with `loop:` directive
  - Not breaking but deprecated and will be removed in future Ansible versions

- **with_nested**: Found in 4 roles (deploy-user, openaustralia, righttoknow, theyvoteforyou)
  - Should be replaced with `loop:` and `product` filter
  - Example: `loop: "{{ list1 | product(list2) | list }}"`

**Deprecated Test:**
- `is success` in `roles/internal/deploy-user/tasks/main.yml:37`
  - Should be `is succeeded`

#### LOW PRIORITY

**YAML Boolean Syntax:**

Multiple roles use old boolean syntax (yes/no/on/off) instead of true/false:
- awscloudwatch (3 occurrences)
- openvpn (4 occurrences)
- openaustralia (5+ occurrences)
- proxy (2 occurrences)
- righttoknow (1 occurrence)
- theyvoteforyou (3 occurrences)

**PostgreSQL Module Parameters:**
- `no_password_changes: true` in metabase and planningalerts
  - Deprecated in community.postgresql collection 3.x
  - Consider removing or replacing with `check_implicit_admin`

---

### Terraform/OpenTofu Issues

#### HIGH PRIORITY

**Remaining aws_eip Resources with Deprecated instance Argument:**

These files still use the deprecated pattern and need migration:

1. `/home/user/infrastructure/terraform/theyvoteforyou/main.tf:33-38`
2. `/home/user/infrastructure/terraform/openaustralia/main.tf:25-30`
3. `/home/user/infrastructure/terraform/openaustralia/production.tf:27-32`
4. `/home/user/infrastructure/terraform/proxy/main.tf:26-31`
5. `/home/user/infrastructure/terraform/metabase/main.tf:25-30`
6. `/home/user/infrastructure/terraform/plausible/main.tf:27-32`
7. `/home/user/infrastructure/terraform/righttoknow/production.tf:34-40`
8. `/home/user/infrastructure/terraform/righttoknow/staging.tf:33-39`

**Remaining aws_s3_bucket_acl Resources:**

1. `/home/user/infrastructure/terraform/backups-orpington.tf:60`
2. `/home/user/infrastructure/terraform/backups.tf:62`
3. `/home/user/infrastructure/terraform/elasticsearch-snapshots.tf:50`

#### MEDIUM PRIORITY

**Provider Version Conflicts:**

16+ module files have local `required_providers` blocks with old versions that conflict with root:

**Files with Cloudflare 4.4.0 (should inherit 4.48.0 from root):**
- aws-certificate/main.tf
- campaign-monitor/dns.tf
- cuttlefish/main.tf
- electionleaflets/main.tf
- metabase/main.tf
- morph/main.tf
- oaf/main.tf
- openaustralia/main.tf
- planningalerts/main.tf
- planningalerts/env/main.tf
- plausible/main.tf
- proxy/main.tf
- social/dns.tf
- righttoknow/main.tf
- theyvoteforyou/main.tf

**Recommendation:** Remove `terraform { required_providers { ... } }` blocks from modules to inherit from root versions.tf.

---

## Testing Recommendations

### Before Deploying

1. **Ansible Syntax Check:**
   ```bash
   make install-linters
   make ansible-lint
   make yaml-lint
   ```

2. **Ansible Dry Run:**
   ```bash
   # Test against a specific service
   make check-planningalerts

   # Or test all
   .venv/bin/ansible-playbook site.yml --check --diff
   ```

3. **OpenTofu Validation:**
   ```bash
   make tf-init
   tofu -chdir=terraform validate
   make tf-plan
   ```

### Staged Rollout

1. **Test on Development/Staging First:**
   ```bash
   # Test righttoknow staging
   make check-righttoknow-staging
   make apply-righttoknow-staging
   ```

2. **Monitor Logs:**
   - Watch for deprecation warnings
   - Check for module failures
   - Verify service functionality

3. **Proceed to Production:**
   ```bash
   make check-righttoknow-prod
   make apply-righttoknow-prod
   ```

---

## Migration Checklist

- [x] Update Python from 3.11 to 3.13
- [x] Update Ruby from 2.7 to 3.3
- [x] Update Ansible from 2.10 to 10.x
- [x] Migrate Terraform to OpenTofu 1.9.0
- [x] Update AWS provider from 4.62 to 5.82
- [x] Update Cloudflare provider from 4.4 to 4.48
- [x] Fix postgresql role apt_key/apt_repository
- [x] Fix oaf.certbot role apt_repository
- [x] Fix mysql role Python 2 package
- [x] Fix oaf.backup role include statements
- [x] Fix vpn-server.tf aws_eip deprecation
- [x] Fix backend.tf aws_s3_bucket_acl
- [x] Fix raisely MX record priorities
- [x] Add Google provider to versions.tf
- [ ] Fix remaining apt_key/apt_repository in metabase, openaustralia, righttoknow, theyvoteforyou
- [ ] Fix remaining aws_eip resources (8 files)
- [ ] Fix remaining aws_s3_bucket_acl resources (3 files)
- [ ] Remove provider version blocks from 16+ module files
- [ ] Update loop syntax from with_items/with_nested
- [ ] Update YAML boolean syntax
- [ ] Test on staging environment
- [ ] Test on production environment

---

## Additional Resources

- [Ansible 10.x Porting Guide](https://docs.ansible.com/ansible/latest/porting_guides/porting_guide_10.html)
- [AWS Provider 5.x Upgrade Guide](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-5-upgrade)
- [Cloudflare Provider Documentation](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [OpenTofu 1.9.0 Release Notes](https://github.com/opentofu/opentofu/releases/tag/v1.9.0)

---

## Support

For questions or issues with this migration:
1. Review the [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for step-by-step instructions
2. Check the [MODERNIZATION_SUMMARY.md](MODERNIZATION_SUMMARY.md) for technical details
3. Consult the main [README.md](README.md) for updated setup instructions
