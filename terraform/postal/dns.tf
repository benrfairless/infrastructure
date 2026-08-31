# A records
# Used for the API, management interface, SMTP server and as the MX target

resource "cloudflare_record" "a" {
  zone_id = var.zone_id
  name    = "postal.oaf.org.au"
  type    = "A"
  value   = linode_instance.main.ip_address
}

resource "cloudflare_record" "aaaa" {
  zone_id = var.zone_id
  name    = "postal.oaf.org.au"
  type    = "AAAA"
  value   = cidrhost(linode_instance.main.ipv6, 0)
}

# TXT records

# Global SPF record for the mail server. Domains sending through postal
# reference this instead of the server IPs so the IPs can change in future.
resource "cloudflare_record" "spf" {
  zone_id = var.zone_id
  name    = "spf.postal.oaf.org.au"
  type    = "TXT"
  value   = "v=spf1 ip4:${linode_instance.main.ip_address} ip6:${cidrhost(linode_instance.main.ipv6, 0)} ~all"
}

# Return path domain
# Used as the default MAIL FROM (envelope sender) for all messages sent
# through postal. Aligning this with the sending server fixes the DMARC
# alignment failures caused by cuttlefish using oaf.org.au as the
# Return-Path for every domain (issue #364).

resource "cloudflare_record" "rp_a" {
  zone_id = var.zone_id
  name    = "rp.postal.oaf.org.au"
  type    = "A"
  value   = linode_instance.main.ip_address
}

resource "cloudflare_record" "rp_aaaa" {
  zone_id = var.zone_id
  name    = "rp.postal.oaf.org.au"
  type    = "AAAA"
  value   = cidrhost(linode_instance.main.ipv6, 0)
}

resource "cloudflare_record" "rp_mx" {
  zone_id  = var.zone_id
  name     = "rp.postal.oaf.org.au"
  type     = "MX"
  priority = 10
  value    = "postal.oaf.org.au"
}

resource "cloudflare_record" "rp_spf" {
  zone_id = var.zone_id
  name    = "rp.postal.oaf.org.au"
  type    = "TXT"
  value   = "v=spf1 a mx include:spf.postal.oaf.org.au ~all"
}

# DKIM key for bounce messages postal itself sends from the return path
# domain. The value comes from running `postal default-dkim-record` on the
# server (it's the public half of /opt/postal/config/signing.key).
resource "cloudflare_record" "rp_dkim" {
  zone_id = var.zone_id
  name    = "postal._domainkey.rp.postal.oaf.org.au"
  type    = "TXT"
  value   = "v=DKIM1; t=s; h=sha256; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuda8B3fcPmqoE1r/PVob9StyXtDMcfGmgJBqKbYdYHEDyxr9J2FU2vmHvGLXL/cfaHhZprLy/n4iDEphnA+zYMc+QlYzqgiZH7LdN44SN/fKACouEhqJ52+LLa2u7LD6rKXX6JO6Lg7aGYFw6QdWbkyrftRGOK8cA1N+CS8+ieSWZ82dw72kr2LaZ/l62wiViv3jdckl9bav93qbKlr+TnRjGL7VFjQfyy2uwGFm+V2fuQZNootKv5gKdm5Tdj3WY8rCzlLVC/XTULwraVDx8EDKVEhw5ntDJiuG7OVok4wCsoFseA9iODtZh6s2LOx+W04akQ6PAl5DQVq79kM/JwIDAQAB;"
}

# Route domain
# Incoming email sent to *@routes.postal.oaf.org.au is forwarded directly
# to routes configured in postal.

resource "cloudflare_record" "routes_mx" {
  zone_id  = var.zone_id
  name     = "routes.postal.oaf.org.au"
  type     = "MX"
  priority = 10
  value    = "postal.oaf.org.au"
}

# Click and open tracking

resource "cloudflare_record" "track_a" {
  zone_id = var.zone_id
  name    = "track.postal.oaf.org.au"
  type    = "A"
  value   = linode_instance.main.ip_address
}

resource "cloudflare_record" "track_aaaa" {
  zone_id = var.zone_id
  name    = "track.postal.oaf.org.au"
  type    = "AAAA"
  value   = cidrhost(linode_instance.main.ipv6, 0)
}
