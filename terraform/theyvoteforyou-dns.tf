# Configure the DNSMadeEasy provider
provider "dme" {
  version    = "~> 0.1"
  akey       = "${var.dnsmadeeasy_akey}"
  skey       = "${var.dnsmadeeasy_skey}"
  usesandbox = false
}

# Create an A record
resource "dme_record" "ec2" {
  domainid    = "${var.theyvoteforyou_dme_domainid}"
  ttl         = "${var.theyvoteforyou_dme_ttl}"
  gtdLocation = "DEFAULT"

  type        = "A"
  name        = "ec2"
  value       = "${aws_eip.theyvoteforyou.public_ip}"
}

resource "dme_record" "test_ec2" {
  domainid    = "${var.theyvoteforyou_dme_domainid}"
  ttl         = "${var.theyvoteforyou_dme_ttl}"
  gtdLocation = "DEFAULT"

  type        = "CNAME"
  name        = "test.ec2"
  value       = "ec2"
}

resource "dme_record" "www_ec2" {
  domainid    = "${var.theyvoteforyou_dme_domainid}"
  ttl         = "${var.theyvoteforyou_dme_ttl}"
  gtdLocation = "DEFAULT"

  type        = "CNAME"
  name        = "www.ec2"
  value       = "ec2"
}

resource "dme_record" "www_test_ec2" {
  domainid    = "${var.theyvoteforyou_dme_domainid}"
  ttl         = "${var.theyvoteforyou_dme_ttl}"
  gtdLocation = "DEFAULT"

  type        = "CNAME"
  name        = "www.test.ec2"
  value       = "ec2"
}