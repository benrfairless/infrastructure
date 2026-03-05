.PHONY: ALL venv roles production letsencrypt retry clean clean-all tf-init tf-plan tf-apply check-rtk-prod check-rtk-staging check-planningalerts apply-rtk-prod apply-rtk-staging apply-planningalerts update-github-ssh-keys
ALL: roles .vagrant
ROLES := roles

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

production: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook site.yml

letsencrypt: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook update-ssl-certs.yml

retry: $(ROLES) site.retry
	fnox exec -- .venv/bin/ansible-playbook site.yml -l @site.retry

clean:
	rm -rf .venv roles/external site.retry collections
	
clean-all: clean
	rm -rf .vagrant

# Terraform
tf-init:
	fnox exec -- terraform -chdir=terraform init
tf-plan:
	fnox exec -- terraform -chdir=terraform plan
tf-apply:
	fnox exec -- terraform -chdir=terraform apply

# Checks only
check-righttoknow-all: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow --check --diff
check-righttoknow-staging: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow_staging --check --diff
check-righttoknow-prod: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow_production --check --diff
check-planningalerts: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l planningalerts --check --diff
check-theyvoteforyou: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l theyvoteforyou --check --diff
check-oaf: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l oaf --check --diff
check-openaustralia: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l openaustralia --check --diff
check-metabase: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l metabase --check --diff

# These make changes 
apply-righttoknow-all: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow --diff
apply-righttoknow-staging: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow_staging --diff
apply-righttoknow-prod: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l righttoknow_production --diff
apply-planningalerts: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l planningalerts --diff
apply-theyvoteforyou: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l theyvoteforyou --diff
apply-oaf: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l oaf --diff
apply-openaustralia: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l openaustralia --diff
apply-metabase: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook -i ./inventory/ec2-hosts site.yml -l metabase --diff

# Update ssh keys on all servers
update-github-ssh-keys: $(ROLES)
	fnox exec -- .venv/bin/ansible-playbook site.yml --tags userkeys

yaml-lint: venv
	.venv/bin/yamllint roles/ site.yml update-ssl-certs.yml

ansible-lint: venv
	.venv/bin/ansible-lint roles/ site.yml

lint: venv
	hk run pre-commit --all