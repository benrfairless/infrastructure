---
status: accepted
date: 2026-08-31
---

# Ansible module names are fully qualified

Every module action in this repo names its Ansible collection in full: `ansible.builtin.template`, not `template`;
`community.mysql.mysql_user`, not `mysql_user`. Modern ansible-lint's `fqcn` rule requires it, and the modules
that moved out of ansible-core in 2.10 (`mysql_*`, `postgresql_*`, `cronvar`, `mount`, the `docker_*` family)
only resolve under bare names via redirects that assume the full `ansible` package is installed. Naming the
Ansible collection removes the guesswork about which one a task will actually load, and is a prerequisite for
the toolchain bump in #574.

Ansible collections in use here: `ansible.builtin`, `ansible.posix`, `community.general`, `community.mysql`,
`community.postgresql`, `community.docker`, plus `amazon.aws`/`community.aws`, which are pinned in
`roles/requirements.yml`.

## The exception

`include_tasks`, `import_tasks`, `include_role`, `import_role` and `meta` deliberately keep their short names.
The pinned ansible-lint 5.4 (see `requirements.txt`) has an `unnamed-task` rule that doesn't recognise the
qualified spellings and fails the build on them. They get qualified in the toolchain-bump PR, alongside the
ansible-lint upgrade, and not before.

## A rename is not a substitution

Modern ansible-lint resolves `yum` to `ansible.builtin.dnf`, because current ansible-core redirects one to the
other. On our pinned Ansible 2.10 bundle these are two different modules and `ansible.builtin.yum` exists in its
own right, so taking the linter's suggestion would swap the module rather than qualify it. Qualifying a module
must never change which module runs: `yum` becomes `ansible.builtin.yum`. Treat any other tool-suggested name
that isn't the original with the same suspicion.

## Consequences

The pinned ansible-lint 5.4 has no `fqcn` rule, so **CI does not catch a bare module name**. Until the toolchain
bump lands, this convention is enforced by review alone, and anything merged from a branch cut before the sweep
will reintroduce bare names. `ansible-doc <fully.qualified.name>` inside `.venv` is the quick way to confirm a
name resolves before committing it.
