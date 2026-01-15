.PHONY: ALL venv roles production letsencrypt retry clean clean-all check-1password tf-init tf-plan tf-apply check-rtk-prod check-rtk-staging check-planningalerts apply-rtk-prod apply-rtk-staging apply-planningalerts update-github-ssh-keys
ALL: roles .vagrant

.vagrant:
	VAGRANT_DISABLE_STRICT_DEPENDENCY_ENFORCEMENT=1 vagrant plugin install vagrant-hostsupdater
	touch .vagrant

venv: .venv/bin/activate

.venv/bin/activate: requirements.txt
	test -d .venv || python3 -m virtualenv .venv
	.venv/bin/pip install --upgrade pip virtualenv
	.venv/bin/pip install -Ur requirements.txt
	touch .venv/bin/activate

collections:
	.venv/bin/ansible-galaxy collection install -r roles/requirements.yml

roles/external: venv collections roles/requirements.yml
	.venv/bin/ansible-galaxy install -r roles/requirements.yml -p roles/external

roles: roles/external

production: roles
	.venv/bin/ansible-playbook site.yml

letsencrypt: roles
	.venv/bin/ansible-playbook update-ssl-certs.yml

retry: roles site.retry
	.venv/bin/ansible-playbook site.yml -l @site.retry

clean:
	rm -rf .venv roles/external site.retry collections

clean-all: clean
	rm -rf .vagrant

# Check 1Password CLI is installed and authenticated
check-1password:
	@which op > /dev/null || (echo "1Password CLI not found. Install from https://developer.1password.com/docs/cli/get-started/" && exit 1)
	@op account list > /dev/null 2>&1 || (echo "Not authenticated with 1Password. Run: eval \$$(op signin)" && exit 1)
	@echo "✓ 1Password CLI is installed and authenticated"

# OpenTofu (Terraform alternative)
tf-init:
	tofu -chdir=terraform init
tf-plan:
	tofu -chdir=terraform plan
tf-apply:
	tofu -chdir=terraform apply

# Checks only
check-righttoknow-all: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow --check --diff
check-righttoknow-staging: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow_staging --check --diff
check-righttoknow-prod: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow_production --check --diff
check-planningalerts: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l planningalerts --check --diff
check-theyvoteforyou: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l theyvoteforyou --check --diff
check-oaf: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l oaf --check --diff
check-openaustralia: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l openaustralia --check --diff
check-metabase: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l metabase --check --diff

# These make changes
apply-righttoknow-all: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow --diff
apply-righttoknow-staging: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow_staging --diff
apply-righttoknow-prod: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow_production --diff
apply-planningalerts: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l planningalerts --diff
apply-theyvoteforyou: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l theyvoteforyou --diff
apply-oaf: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l oaf --diff
apply-openaustralia: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l openaustralia --diff
apply-metabase: roles
	.venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l metabase --diff

# Update ssh keys on all servers
update-github-ssh-keys: roles
	.venv/bin/ansible-playbook site.yml --tags userkeys

install-linters: venv
	.venv/bin/pip install --upgrade pip ansible-lint  yamllint

yaml-lint: venv
	.venv/bin/yamllint roles/*.yml site.yml

ansible-lint: venv
	.venv/bin/ansible-lint roles/*.yml site.yml

lint: yaml-lint ansible-lint
