<!-- omit in toc -->
# Automated setup and configuration for most of OpenAustralia Foundation's servers

<!-- vscode-markdown-toc -->
- [Automated setup and configuration for most of OpenAustralia Foundation's servers](#automated-setup-and-configuration-for-most-of-openaustralia-foundations-servers)
  - [Other Documents](#other-documents)
  - [The tools](#the-tools)
  - [Templates](#templates)
  - [Provisioning](#provisioning)
    - [Provisioning local development servers using Vagrant](#provisioning-local-development-servers-using-vagrant)
    - [Provisioning production servers](#provisioning-production-servers)
    - [Forcibly renewing LetsEncrypt certificates on production servers](#forcibly-renewing-letsencrypt-certificates-on-production-servers)
      - [Filtering hosts and/or tasks performed](#filtering-hosts-andor-tasks-performed)
  - [Accessing servers](#accessing-servers)
  - [Deploying](#deploying)
  - [Backups](#backups)
  - [Git Tags](#git-tags)
  - [Mail Catching](#mail-catching)

<!-- vscode-markdown-toc-config
	numbering=false
	autoSave=true
	/vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc -->

## <a name='other-documents'></a>Other Documents

History and background context (including the changelog-style "Updates" entries) has moved to
[docs/history.md](docs/history.md).

See [AGENTS.md](AGENTS.md) for AI Agent guidelines.

See [CONTEXT.md](CONTEXT.md) for the glossary: the words this repo uses and the ones it avoids.

See [docs/adr/](docs/adr/) for architecture decision records, one numbered file per cross-cutting decision that
isn't tied to a single file or area.

One-time setup instructions (prerequisites, credentials, the Ansible Vault password, and generating dev SSL certificates) have moved to [INSTALL.md](INSTALL.md).

## <a name='the-tools'></a>The tools

To get a completely working server and service up and running requires a number
of different tools. We use different tools for different things.

- Terraform: To spin up servers, manage DNS and IP addresses, and setting up any
  related AWS infrastructure
- Ansible: To configure individual servers - install packages, create directory
  structures, install SSL certificates, configure cron jobs, create databases,
  etc..
- Vagrant: For local development of the Ansible setups for the servers. The
  vagrant boxes are not designed for doing application development. For that
  go to the individual application repositories.
- Capistrano: For application deployment. This is what installs the actual
  web application and updates the database schema.

Each application has its own repository and this is where application deployment
is done from. This repository just contains the Terraform and Ansible configuration
for the servers.

A little note on terminology, defined in full in [CONTEXT.md](CONTEXT.md):

- "assembling" - using Terraform to create/update the infrastructure a host needs (EC2 instances, RDS databases,
  DNS, load balancers, etc.), before Ansible ever touches it.
- "provisioning" - configuring a host with Ansible.
- "deployment" - installing or updating the web application with Capistrano, from the app's own repo.

## <a name='templates'></a>Templates

Every file rendered through Ansible's `template:` module **must** use a `.j2`
extension (for example `general.yml.j2`, `nginx.conf.j2`, `sidekiq.service.j2`).
This keeps Jinja2 templates visually distinct from finished config files and keeps
them out of the YAML/JSON linters, which would otherwise try to parse the
un-rendered template.

- Give the template file its content extension followed by `.j2`
  (`database.yml` becomes `database.yml.j2`). The `src:` in the task must match; the
  `dest:` keeps the real filename with no `.j2`. When `dest:` is a directory, name the
  file explicitly (`dest: /srv/www/production/shared/general.yml`) - Ansible does not
  strip `.j2` for you.
- If a file has no Jinja2 (`{{ ... }}` / `{% ... %}`) it is not a template. Put it in
  the role's `files/` directory and use `copy:` instead.

`make template-check` enforces this - it fails if any file under an internal
role's `templates/` directory does not end in `.j2`, and it runs in CI.
Third-party roles under `roles/external/` are not checked, as we don't control
their layout.

## <a name='provisioning'></a>Provisioning

### <a name='provisioning-local-development-servers-using-vagrant'></a>Provisioning local development servers using Vagrant

In development, you set up and provision a server using Vagrant. You probably only want to run
one main server and the mysql server, so you can bring it up with:

    vagrant up mysql.test web.planningalerts.test

If it's already up, you can re-run Ansible provisioning with:

    vagrant provision oaf

Or combine with:

    vagrant up --provision staging.righttoknow.test

### <a name='provisioning-production-servers'></a>Provisioning production servers

First use the `make check-<site>` commands to check what will change is as you expect.
If necessary, skip specific tags to skip over areas that fail on check, eg:

    SKIP_TAGS=mount_data,xapian make check-openaustralia

Provision all running servers (production and staging) with:

    make all

This will create a Python virtualenv in `venv`; install ansible inside it; and install required roles from ansible-galaxy inside `roles/external`

If you just want to provision a single server:

    make apply-planningalerts

or where there are multiple servers, specify which one you want to provision:

     STAGE=old make apply-openaustralia

To provision all stages, just specify `STAGE=all`

The repo will be tagged `wip-TARGET_UTC-TIME[_STAGE][-TAGS][-not-SKIP_TAGS]` before the command starts,
which will be replaced with `TARGET_UTC-TIME[_STAGE][-TAGS][-not-SKIP_TAGS]` upon success.
With tags pushed to origin, so everyone can see what was changed on servers.

The postal mail server needs Terraform and some one-off manual steps as well as Ansible -
see [docs/POSTAL.md](docs/POSTAL.md).

### <a name='forcibly-renewing-letsencrypt-certificates-on-production-servers'></a>Forcibly renewing LetsEncrypt certificates on production servers

When first provisioning a server, Ansible will check to see if
`certbot_webroot` is set (this is used on RightToKnow). If not, it
looks for `certbot_webserver`. If that's not set either, Ansible
assumes that the web server is Apache.

Ansible then installs and configures Certbot, and uses it to create
certificates for all domains listed in `certbot_certs`.

Code for this is in the [oaf.certbot role](https://github.com/openaustralia/infrastructure/blob/9d251b5e86623efaadcd1ee39dc429cfb6f95607/roles/internal/oaf.certbot/tasks/main.yml#L16).

Sample config at [RTK](https://github.com/openaustralia/infrastructure/blob/9d251b5e86623efaadcd1ee39dc429cfb6f95607/roles/internal/righttoknow/tasks/certificates.yml#L47).

After this, Certbot runs from cron (or systemd) and renews
certificates automatically with no downtime.

In the unlikely event that you need to forcibly renew certificates:

    make letsencrypt

will use Ansible to forcibly renew every already-registered
certificate, using the same `cerbot_webserver` and `certbot_webroot`
config.

If you want to forcibly renew just one service, instructions are in
the top of `update-ssl-certs.yaml`.

#### Filtering hosts and/or tasks performed

You can also set:

- STAGE: to a group suffix eg `STAGE=staging make apply-righttoknow` would apply changes only to `righttoknow_staging`
  group in `inventory/ec2-hosts` which only contains `staging.openaustralia.org.au`
- `ANSIBLE_TAGS` - limits to tasks / roles that have one of the comma-separated roles
- `ANSIBLE_SKIP_TAGS` - skips tasks / roles that have one of the comma-separated roles
- `ANSIBLE_VERBOSE` - set to one to four 'v's eg `ANSIBLE_VERBOSE=vvv make apply-openaustralia` will show a lot of diagnostic information from ansible
- `ANSIBLE_START_TASK` - set to part of the task description to have ansible skip to that task, which allows you to quickly debug after a failure

## <a name='accessing-servers'></a>Accessing servers

Direct SSH access is being phased out in favour of AWS SSM Session Manager. For any instance with a
`PublicHostname` tag set:

    make ssh-config

prints an OpenSSH `~/.ssh/config` block - one `Host` entry per instance, aliased by its public hostname, `Name`
tag, and instance ID, proxying through SSM rather than a direct network connection. Paste the output into your
own `~/.ssh/config` yourself; it's not written there automatically. Re-run and re-paste after any instance
replacement (blue/green cutover, AMI refresh, etc.), since the resolved instance IDs go stale.

For a quick fleet-wide health check:

    make server-status

runs `uptime`, `free -m`, `df` (space and inodes), and a failed-systemd-units check against every host in
inventory. Scope it to one host or group with `HOST=<host-or-group>`, e.g. `make server-status
HOST=planningalerts`.

## <a name='deploying'></a>Deploying

Deployment is service-specific - see:

- Right To Know: see [docs/righttoknow.md](docs/righttoknow.md)
- PlanningAlerts: see [docs/planningalerts.md](docs/planningalerts.md)
- They Vote For You (including "Running tests locally"): see [docs/theyvoteforyou.md](docs/theyvoteforyou.md)
- OpenAustralia: see [docs/openaustralia.md](docs/openaustralia.md)

## <a name='backups'></a>Backups

Data directories are backed up to the `oaf-backups` S3 bucket using [restic](https://restic.net/), configured by
`roles/internal/oaf.restic`. Two hosts are covered, both backing up `/data`: openaustralia, and righttoknow
production. Each is a restic profile, `openaustralia_data` and `righttoknow_data`. Right to Know staging and the
other services (They Vote For You, PlanningAlerts, Metabase, Postal) have no file-level backups; their databases
are covered by RDS automated snapshots instead.

Each profile gets an environment file at `/etc/restic/<profile>.env`, a passphrase file at
`/etc/restic/<profile>-password`, a wrapper script at `/usr/local/bin/restic-backup-<profile>`, a cron entry in
`/etc/cron.d/restic-<profile>` running at 03:00, and a log at `/var/log/restic/<profile>.log`. The environment file
holds the S3 credentials in plaintext, so don't copy it around. Every `restic` command below needs it sourced
first, which sets the repository, the passphrase file and those credentials.

To run a backup manually, log in as root and run the wrapper. It takes a lockfile, so it won't collide with the
cron run:

    /usr/local/bin/restic-backup-righttoknow_data

To see what's in the repository:

    source /etc/restic/righttoknow_data.env && restic snapshots

To restore the most recent snapshot to `/mnt/restore`:

    source /etc/restic/righttoknow_data.env && restic restore latest --target /mnt/restore

`restic mount /mnt/restore` instead exposes every snapshot as a browsable filesystem, which is usually the better
way to retrieve a handful of files. Note that the restore path has not been rehearsed against a live repository, so
treat a real restore as unproven until someone has done a drill.

Retention and integrity checking run on Sundays only, after that night's backup: `restic forget --keep-daily 7
--keep-weekly 4 --keep-monthly 6 --prune`, then `restic check`.

The repository path is derived from `log_name`, not `public_hostname`, so replacing an instance keeps its backup
history as long as the `LogName` tag is carried over. See the comment in `terraform/righttoknow/staging.tf` and the
`restic_profiles` blocks in `roles/internal/righttoknow/meta/main.yml` and
`roles/internal/openaustralia/meta/main.yml`.

## <a name='git-tags'></a>Git Tags

The make `apply-*` and `tf-apply*` targets create a git tag before and after the command to actually change the
infrastructure is called so it is clear what has and hasn't been fully actioned. A `wip-*` tag that sticks around
indicates a failed provisioning command.

The `bin/tag-provisioning` command is called to tag the latest commit. Specifically it:

1. creates a git tag with `wip-` prefix to indicate that changes to infrastructure had been started and pushes it to GitHub;
2. runs the requested command;
3. creates the git tag without the `wip-` prefix and pushes it to GitHub;
4. removes the wip git tag locally and on GitHub, so it is clear the command succeeded.

Terraform tags (from `make tf-apply`) will start with `[wip-]terraform` and then have the timestamp, eg
`terraform_20260717125154`.

Ansible tags (from `make apply-*`) will start with the service being targetted, and then have the timestamp, followed
by the `STAGE`, `TAGS`, and `SKIP_TAGS` values, if set.

## <a name='mail-catching'></a>Mail Catching

Mail catching configuration has moved to [docs/openaustralia.md](docs/openaustralia.md).
