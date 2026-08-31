---
status: accepted
date: 2026-08-31
---

# Duplicity is replaced by restic, and the duplicity archives are written off

Duplicity (the vendored `oaf.backup` role, a fork of `Stouts.backup`) backed up host data directories to the
`oaf-backups` S3 bucket via duply. It was replaced by restic (`oaf.restic`) in
[41f3fe2e](https://github.com/openaustralia/infrastructure/commit/41f3fe2e) on 2025-12-24. Restic deduplicates and
compresses, so the same data costs far less to store: righttoknow 311 GiB to 63 GiB, openaustralia 55.6 GiB to
15.5 GiB, oaf 4.6 GiB to 138 MiB. Duplicity had also been silently failing on openaustralia since August 2024 due
to a stale lockfile, so one of the two remaining profiles was not producing backups at all.

That migration switched the live path over but left the old role, its variables and its documentation in place.
This ADR records both the original decision and the cleanup that finished it
([#722](https://github.com/openaustralia/infrastructure/issues/722)).

## Consequences

Consequences that span the repo:

- `oaf.backup` and everything that only fed it is deleted. The duplicity-era variables (`backup_profiles`,
  `backup_gpg_pw`, `backup_max_age`, `backup_max_full_backups`, `backup_full_max_age`, `backup_enabled`) are gone;
  `backup_target_user` and `backup_target_pass` in `group_vars/all.yml` keep their duply-era names because
  `oaf.restic` reads them for its S3 credentials.
- **The pre-December-2025 duplicity archives are unrecoverable.** Duplicity used symmetric GPG encryption, and the
  passphrase existed only as the `backup_gpg_pw` vault values now deleted. Roughly 583 GiB of `.gpg` objects remain
  in the bucket and can no longer be decrypted by anyone. This was a deliberate trade-off: restic has been running
  since the cutover, and keeping a passphrase in the repo for archives nobody was going to restore was worse than
  losing the history. Deleting that data from S3 is a follow-up on #722.
- **Backups are production-only.** Both `oaf.restic` invocations back up `/data` on openaustralia and righttoknow
  production. Right to Know staging has none, deliberately. They Vote For You, PlanningAlerts, Metabase and Postal
  have no file-level backups either; their data is covered by RDS automated snapshots (32-day retention) and, for
  the Linode hosts, Linode's own snapshot service. There are no EBS snapshot schedules.
- Retention is enforced by restic rather than by S3. `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6
  --prune` plus `restic check` run on Sundays. The bucket has no lifecycle configuration, and any that is added
  must be scoped to the retired `data/` prefixes: a bucket-wide expiry rule would delete pack files that live
  restic snapshots still reference, corrupting the repositories.
- A retired role does not clean up after itself. `oaf.backup`'s uninstall path was gated on `backup_remove`, which
  was never set, so disabling the role left its cron entries, config and packages on the hosts. Right to Know
  staging kept backing up for eight months as a result. Removing a provisioning role in future means removing what
  it installed from the hosts as well, by hand or with a cleanup role (see `remove_rvm` and siblings).
