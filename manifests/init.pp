# == Class: acme_certificates
#
# Configures the default settings for certificates managed by this puppet module and optionally installs required gems.
#
# === Parameters
#
# [*manage_gems*]
#   Whether to install the required ruby gems to make the custom providers of this puppet module work. Defaults to false.
#
# [*contact*]
#   The contact information used to register with the ACME server.
#   e.g. 'mailto:cert-admin@example.com' or 'tel:+12025551212'
#
# [*directory*]
#   The ACME server's directory URL. Defaults to the Let's Encrypt staging environment.
#
# [*agree_to_terms_url*]
#   The URL of the terms of service of the ACME server to agree to. By setting this, you agree to the terms of service of the ACME server.
#   This must be set if the ACME server requires ACME clients to agree to terms of service.
#
# [*authorization_timeout*]
#   The time, in seconds, to wait for the ACME server to process pending domain authorizations before timing out. Defaults to 5 minutes.
#
# [*renew_within_days*]
#   If an existing certificate would expire within this many days, it will be renewed. Defaults to 30 days.
#
# [*acme_private_key_path*]
#   The path to the private key file to use for ACME registration (not the certificate private key). If specified, this file must already exist.
#   Defaults to the puppet agent's private key.
#
# [*aws_access_key_id*]
#   The AWS Access Key ID to use to modify Route 53 records to authorize domains.
#   Defaults to no credentials (e.g. will use the AWS SDK default methods for finding credentials, or fail trying to look them up)
#
# [*aws_secret_access_key*]
#   The AWS Secret Access Key to use to modify Route 53 records to authorize domains.
#   Defaults to no credentials (e.g. will use the AWS SDK default methods for finding credentials, or fail trying to look them up)
#
# [*route53_zone_id*]
#   The Route 53 zone ID to create DNS records in to authorize domains.
#
# === Examples
#
#  class { 'acme_certificates':
#    manage_gems        => true,
#    contact            => 'mailto:cert-admin@example.com',
#    directory          => 'https://acme-v01.api.letsencrypt.org/directory',
#    agree_to_terms_url => 'https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf',
#  }
#
# === Copyright
#
# Copyright 2016 Nicholas Hinds, unless otherwise noted.
#
class acme_certificates(
  $manage_gems           = false,
  $contact               = undef,
  $directory             = 'https://acme-staging.api.letsencrypt.org/directory',
  $agree_to_terms_url    = undef,
  $authorization_timeout = 300,
  $renew_within_days     = 30,
  $acme_private_key_path = undef,
  $aws_access_key_id     = undef,
  $aws_secret_access_key = undef,
  $route53_zone_id       = undef,
) {
  if $manage_gems {
    include acme_certificates::gems
  }
}
