# == Class: acme_certificates
#
# Configures the default settings for certificates managed by this puppet module.
#
# === Parameters
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
# === Examples
#
#  class { 'acme_certificates':
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
  $contact            = undef,
  $directory          = 'https://acme-staging.api.letsencrypt.org/directory',
  $agree_to_terms_url = undef,
) {
}
