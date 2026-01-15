# Provider versions inherited from root versions.tf

# For mastodon hosting

resource "cloudflare_record" "root" {
  zone_id = var.zone_id
  name    = "social.oaf.org.au"
  type    = "CNAME"
  value   = "vip.masto.host"
}
