# Postal mail server

The [Postal](https://github.com/postalserver/postal) mail server (postal.oaf.org.au) replaces cuttlefish. Unlike cuttlefish and morph.io, whose provisioning lives in their own application repositories, postal is assembled **and** provisioned from this repository. See [docs/adr/0002-postal-replaces-cuttlefish.md](adr/0002-postal-replaces-cuttlefish.md) for why we moved off cuttlefish.

## Setting up the server

Postal is assembled with Terraform (`terraform/postal/` - Linode instance, reverse DNS and Cloudflare DNS records) and provisioned with Ansible (`roles/internal/postal/` - Docker, MariaDB, the official [postalserver/install](https://github.com/postalserver/install) helper and Caddy for SSL termination):

    make tf-plan-target MODULE=postal   # then tf-apply-target when happy
    make check-postal
    make apply-postal

## One-off manual steps after the first provisioning run

1. Create a global admin user: SSH to the server and run `postal make-user`
2. Add the DKIM record for the return path domain: run `postal default-dkim-record` on the server and add the TXT record it prints (`postal._domainkey.rp.postal.oaf.org.au`) to `terraform/postal/dns.tf`
3. Log into <https://postal.oaf.org.au> and create one organisation (OAF) with a mail server per application:
   `theyvoteforyou`, `openaustralia`, `morph`, `metabase`, `planningalerts` and `planningalerts-comments`
   (PlanningAlerts uses a second mail server for the comment emails it sends to councils - see
   [docs/adr/0003-planningalerts-gets-two-postal-mail-servers.md](adr/0003-planningalerts-gets-two-postal-mail-servers.md))
4. On each mail server, add its sending domain (which will show the per-domain SPF/DKIM records to add to that
   domain's `dns.tf`), generate SMTP credentials, enable click/open tracking with an `email3.<domain>` track
   domain (following the `email`/`email2` cuttlefish convention; skip tracking for metabase - it only sends
   internal mail - and for planningalerts-comments - official correspondence to councils isn't tracked), and for
   the two PlanningAlerts mail servers add a webhook pointing at the app's Postal event endpoint.
   `theyvoteforyou` gets a second credential for its staging stage and `morph` gets a second credential for
   Discourse (discuss.morph.io). Each track domain hostname needs a CNAME to `track.postal.oaf.org.au` in that
   domain's `dns.tf` and an entry in `postal_track_domains` (role defaults), which makes Caddy serve it with a
   Let's Encrypt certificate
5. Generate SMTP credentials for postal's own system emails and set `postal_system_smtp_username`/`postal_system_smtp_password` (vaulted) in `group_vars/postal.yml`. Until this is done postal can't send its own system emails (e.g. password resets). The credential must belong to a mail server with oaf.org.au as a sending domain, so system mail from `postal@oaf.org.au` is DKIM-signed and DMARC-aligned

## How applications connect

Applications submit mail to `postal.oaf.org.au` port **2525** (AWS EC2 blocks outbound port 25 by default, so the
host redirects 2525 to postal's SMTP listener on 25 - see `redirect-smtp-port` in the role). The SMTP server does
STARTTLS with Caddy's Let's Encrypt certificate (synced across by `sync-smtp-certificate`, daily via cron), so
clients should verify the certificate - no `tls_certcheck off` style workarounds.

## Upgrades

Upgrades are deliberately manual: bump `postal_version` in `roles/internal/postal/defaults/main.yml`, then run `postal upgrade <version>` on the server (which pulls the install helper repo and migrates the database).

## Linode SMTP port restrictions

Linode blocks SMTP ports on newly created instances for some accounts - if outbound port 25 is blocked, open a Linode support ticket to lift it.
