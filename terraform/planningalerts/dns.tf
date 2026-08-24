resource "cloudflare_zone" "main" {
  account_id = var.cloudflare_account_id
  plan       = "business"
  zone       = "planningalerts.org.au"
}

# A records

locals {
  # Only include environment if the weight is set to 1. This is a very hacky way of doing something
  # like the weighting on the load balancer for the round robin DNS below
  planningalerts_all_public_ips = concat(
    var.blue_weight == 1 ? module.blue.public_ips : [],
    var.green_weight == 1 ? module.green.public_ips : []
  )
}

# Round-robin DNS - doing this to avoid having to put in a network load balancer which would cost us money obviously
resource "cloudflare_record" "incoming_email" {
  count   = length(local.planningalerts_all_public_ips)
  zone_id = cloudflare_zone.main.id
  name    = "incoming.email.planningalerts.org.au"
  type    = "A"
  value   = local.planningalerts_all_public_ips[count.index]
}

# CNAME records

resource "cloudflare_record" "root" {
  zone_id = cloudflare_zone.main.id
  name    = "planningalerts.org.au"
  type    = "CNAME"
  value   = var.load_balancer.dns_name
  proxied = false
}

resource "cloudflare_record" "www" {
  zone_id = cloudflare_zone.main.id
  name    = "www.planningalerts.org.au"
  type    = "CNAME"
  value   = var.load_balancer.dns_name
  proxied = false
}

resource "cloudflare_record" "api" {
  zone_id = cloudflare_zone.main.id
  name    = "api.planningalerts.org.au"
  type    = "CNAME"
  value   = var.load_balancer.dns_name
  proxied = false
}

resource "cloudflare_record" "email2" {
  zone_id = cloudflare_zone.main.id
  name    = "email2.planningalerts.org.au"
  type    = "CNAME"
  value   = "cuttlefish.oaf.org.au"
}

# Click/open tracking for mail sent through postal (the planningalerts
# mail server only - comment emails to councils are not tracked)
resource "cloudflare_record" "email3" {
  zone_id = cloudflare_zone.main.id
  name    = "email3.planningalerts.org.au"
  type    = "CNAME"
  value   = "track.postal.oaf.org.au"
}

# DKIM records for mail sent through postal - one per mail server
# (planningalerts and planningalerts-comments, see ADR 0003). The values
# come from the domain's page on each mail server in the postal web
# interface.
resource "cloudflare_record" "postal_domainkey" {
  zone_id = cloudflare_zone.main.id
  name    = "postal-E79yJc._domainkey.planningalerts.org.au"
  type    = "TXT"
  value   = "v=DKIM1; t=s; h=sha256; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDBw6JQtx7W9F+pDNu74ZqC7xiDnmp6qPJNY6NIAF9tANWtZb9DqOQFtdqqFqgzFoeo8Sl6L9VUca3I7Jv2Ta1bIPkZjizDl3kUBrfGXUlrc6ZjQxcQACI5LBCcfnge42JoAIJ/1iRBsuuI8i8rxHSVsGxPqIF2C0U8DgWYqn39SwIDAQAB;"
}

resource "cloudflare_record" "postal_domainkey2" {
  zone_id = cloudflare_zone.main.id
  name    = "postal-EhMmez._domainkey.planningalerts.org.au"
  type    = "TXT"
  value   = "v=DKIM1; t=s; h=sha256; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDqJL4C7BCQuDPH7CoAiUibRaOIpgyAUYeWLNwQuruCQNpZXk2hPkfRfXzk27eh4/lTQsZMCsZKogqPK+5iPZi3yyvCqJrvzs5q6MR1XqDamQTRHEuZYNayePzUFtlPTEZ8zm4fhDccakFbeKH+eiKObF14Q8gGmhOTX0jgWyy6HQIDAQAB;"
}

# Custom Return-Path (MAIL FROM) host for mail sent through postal, so the
# Return-Path domain aligns with the From domain for DMARC
resource "cloudflare_record" "psrp" {
  zone_id = cloudflare_zone.main.id
  name    = "psrp.planningalerts.org.au"
  type    = "CNAME"
  value   = "rp.postal.oaf.org.au"
}

resource "cloudflare_record" "donate" {
  zone_id = cloudflare_zone.main.id
  name    = "donate.planningalerts.org.au"
  type    = "CNAME"
  value   = "hosting.raisely.com"
}

resource "cloudflare_record" "helpscout_dkim_strong1" {
  zone_id = cloudflare_zone.main.id
  name    = "strong1._domainkey.planningalerts.org.au"
  type    = "CNAME"
  value   = "strong1._domainkey.helpscout.net"
  proxied = false
}

resource "cloudflare_record" "helpscout_dkim_strong2" {
  zone_id = cloudflare_zone.main.id
  name    = "strong2._domainkey.planningalerts.org.au"
  type    = "CNAME"
  value   = "strong2._domainkey.helpscout.net"
  proxied = false
}

# MX records

# We can now use a single MX record for Google workspace
resource "cloudflare_record" "mx" {
  zone_id  = cloudflare_zone.main.id
  name     = "planningalerts.org.au"
  type     = "MX"
  priority = 1
  value    = "smtp.google.com"
}

# TXT records

resource "cloudflare_record" "spf" {
  zone_id = cloudflare_zone.main.id
  name    = "planningalerts.org.au"
  type    = "TXT"
  value   = "v=spf1 include:_spf1.oaf.org.au include:_spf.google.com a:cuttlefish.oaf.org.au include:spf.postal.oaf.org.au -all"
}

resource "cloudflare_record" "google_site_verification" {
  zone_id = cloudflare_zone.main.id
  name    = "planningalerts.org.au"
  type    = "TXT"
  value   = "google-site-verification=wZp42fwpmr6aGdCVqp7BJBn_kenD51hYLig7cMOFIBs"
}

resource "cloudflare_record" "facebook_domain_verification" {
  zone_id = cloudflare_zone.main.id
  name    = "planningalerts.org.au"
  type    = "TXT"
  value   = "facebook-domain-verification=djdz2wywxnas3cxhrch14pfk145g93"
}

resource "cloudflare_record" "yahoo_domain_verification" {
  zone_id = cloudflare_zone.main.id
  name    = "planningalerts.org.au"
  type    = "TXT"
  value   = "yahoo-verification-key=j/JGsx5QsyhsESucFAGKelmOmW80kCYKW5lxhkxvzr4="
}


resource "cloudflare_record" "domainkey" {
  zone_id = cloudflare_zone.main.id
  name    = "planningalerts_3.cuttlefish._domainkey.planningalerts.org.au"
  type    = "TXT"
  value   = "k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoUPCB2huZQkwFnEMn0/jorQ/nHsNul1gQqHbQsX2unANX+dXnnmF0y+rFnB93mlmOVemv+vnQik/DGr+3aCQqOia5t5xXTsbPenmstC1tfCNDl9irQb7sCP8IeiLdcxJ5upsH8PtAod9r7J/Uo8KdXxMPbBFvVT/X9qe25dHkZUqwJHGn7peLmSTe2Ti4ZRTlyolc1orKD7sHx7iI+lU/9Ga1at2kykrXGAs4bUDPY2cmsSMcwqYRu6DQgBz01g9pqaOmDZ7mKwbI7M2m9kX6AWFCb9YqyeyZpW42bytlsKiVsH5bwQmhNFJ/vqTuwyyvBlIDcforixhRGZ13Ufj2QIDAQAB"
}

resource "cloudflare_record" "domainkey_google" {
  zone_id = cloudflare_zone.main.id
  name    = "google._domainkey.planningalerts.org.au"
  type    = "TXT"
  value   = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkUq+EPS6XemyHdVi5CCW7+M+X1XMrAg85Y2oYEUYVcB2IU+1HF/fGUdY9w8wvphSC/28wznJOOTl92pj6/DvwRcfpogRrjITYmPZQMOC0SQ4/4nOeL5ug6fNWFg74LZQvQJqWGAQuUhiSiwxUpkUHAv6H5iE/EKDVOdeWjPWjsIkoAC5HdAie0WCcq3gDlfDJZ3L6K7/nGorPd96764EYG/pdsN43/jzcU23vVGJlhw9my1jvkxNnMS1xRkUuk/JcCIRWp4RkgQOkK7JEoNXB2u+bgW+8mLlGX66dag2l67CR+qzOuE1nHcOu5ADLqVh42MOTNMhw75TzugEbtn0QQIDAQAB"
}

# DMARC delegated to Suped via CNAME (https://suped.com/).
# Record content and policy (p=) are managed in the Suped dashboard, not here.
resource "cloudflare_record" "dmarc" {
  zone_id = cloudflare_zone.main.id
  name    = "_dmarc.planningalerts.org.au"
  type    = "CNAME"
  value   = "planningalerts.org.au.dmarc.dns.suped.com"
}
