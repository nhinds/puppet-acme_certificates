# == Define: acme_certificates::cert
#
# Manage a certificate on disk signed by an ACME server.
#
# === Parameters
#
# [*common_name*]
#   The common name of the certificate.
#
# [*private_key_path*]
#   The path to the private key file. If generate_private_key is not true, this file must already exist.
#
# [*certificate_path*]
#   The file to place the signed certificate in. Defaults to the title
#
# [*certificate_chain_path*]
#   The file to place the certificate chain in. Defaults to not writing the certificate chain to disk
#
# [*combine_certificate_and_chain*]
#   Whether to write out the certificate and chain to the single file identified by certificate_path.
#   Defaults to not combining certificate and chain
#
# [*alternate_names*]
#   Subject alternate names of the certificate. Defaults to no alternate names
#
# [*generate_private_key*]
#   Whether to automatically generate a private key for this certificate. Defaults to not generating the private key
#
# [*owner*]
#   The file owner for the generated certificate, certificate chain, and private key files. Defaults to root
#
# [*group*]
#   The file group for the generated certificate, certificate chain, and private key files. Defaults to root
#
# [*certificate_mode*]
#   The file mode for the generated certificate file. Defaults to '0444'
#
# [*certificate_chain_mode*]
#   The file mode for the generated certificate chain file, if $certificate_chain_path is specified. Defaults to '0444'
#
# [*private_key_mode*]
#   The file mode for the generated private key file, if $generate_private_key is true. Defaults to '0400'
#
# [*contact*]
#   The contact information used to register with the ACME server.
#   e.g. 'mailto:cert-admin@example.com' or 'tel:+12025551212'
#   Defaults to the value from the acme_certificates class
#
# [*directory*]
#   The ACME server's directory URL.
#   Defaults to the value from the acme_certificates class
#
# [*agree_to_terms_url*]
#   The URL of the terms of service of the ACME server to agree to. By setting this, you agree to the terms of service of the ACME server.
#   This must be set (in the certificate resource or in the acme_certificates class) if the ACME server requires ACME clients to agree to
#   terms of service.
#   Defaults to the value from the acme_certificates class
#
# [*authorization_timeout*]
#   The time, in seconds, to wait for the ACME server to process pending domain authorizations before timing out.
#   Defaults to the value from the acme_certificates class
#
# [*renew_within_days*]
#   If an existing certificate would expire within this many days, it will be renewed.
#   Defaults to the value from the acme_certificates class
#
# [*acme_private_key_path*]
#   The path to the private key file to use for ACME registration (not the certificate private key). If specified, this file must already exist.
#   Defaults to the value from the acme_certificates class
#
# [*aws_access_key_id*]
#   The AWS Access Key ID to use to modify Route 53 records to authorize the domain for this certificate.
#   Defaults to the value from the acme_certificates class
#
# [*aws_secret_access_key*]
#   The AWS Secret Access Key to use to modify Route 53 records to authorize the domain for this certificate.
#   Defaults to the value from the acme_certificates class
#
# [*route53_zone_id*]
#   The Route 53 zone ID to create DNS records in to authorize the domain for this certificate.
#   Defaults to the value from the acme_certificates class
#
# === Examples
#
#  acme_certificates::cert { '/etc/ssl/certs/www.example.com.pem':
#    private_key_path     => '/etc/ssl/private/www.example.com.key',
#    common_name          => 'example.com',
#    alternate_names      => ['www.example.com', 'web.example.com'],
#    generate_private_key => true,
#  }
#
# === Copyright
#
# Copyright 2016 Nicholas Hinds, unless otherwise noted.
#

define acme_certificates::cert(
  $common_name,
  $private_key_path,
  $certificate_path = $title,
  $certificate_chain_path = undef,
  $combine_certificate_and_chain = false,
  $alternate_names = [],
  $generate_private_key = false,
  $owner = root,
  $group = root,
  $certificate_mode = '0444',
  $certificate_chain_mode = '0444',
  $private_key_mode = '0400',
  $contact = undef,
  $directory = undef,
  $agree_to_terms_url = undef,
  $authorization_timeout = undef,
  $renew_within_days = undef,
  $acme_private_key_path = undef,
  $aws_access_key_id = undef,
  $aws_secret_access_key = undef,
  $route53_zone_id = undef,
) {
  include acme_certificates

  validate_bool($combine_certificate_and_chain, $generate_private_key)
  validate_absolute_path($certificate_path, $private_key_path)
  if $certificate_chain_path {
    validate_absolute_path($certificate_chain_path)
  }
  validate_array($alternate_names)
  validate_string($owner, $group, $certificate_mode, $certificate_chain_mode, $private_key_mode)

  $_contact = pick_default($contact, $::acme_certificates::contact)
  if empty($_contact) {
    fail('Must specify `contact` in acme_certificates::cert or acme_certificates')
  }
  # TODO validate syntax (mailto: / tel:)

  $_directory = pick_default($directory, $::acme_certificates::directory)

  # $agree_to_terms_url is optional in the ACME spec - it is required by Let's Encrypt, but ACME servers in general may not require this
  $_agree_to_terms_url = pick_default($agree_to_terms_url, $::acme_certificates::agree_to_terms_url)

  $_authorization_timeout = pick($authorization_timeout, $::acme_certificates::authorization_timeout)
  $_renew_within_days = pick($renew_within_days, $::acme_certificates::renew_within_days)
  $_acme_private_key_path = pick_default($acme_private_key_path, $::acme_certificates::acme_private_key_path)
  $_aws_access_key_id = pick_default($aws_access_key_id, $::acme_certificates::aws_access_key_id)
  $_aws_secret_access_key = pick_default($aws_secret_access_key, $::acme_certificates::aws_secret_access_key)
  $_route53_zone_id = pick_default($route53_zone_id, $::acme_certificates::route53_zone_id)
  validate_string($_contact, $_directory, $_agree_to_terms_url, $_aws_access_key_id, $_aws_secret_access_key, $_route53_zone_id)
  validate_integer($_authorization_timeout)
  validate_integer($_renew_within_days)
  if $_acme_private_key_path and !empty($_acme_private_key_path) {
    validate_absolute_path($_acme_private_key_path)
  }

  acme_certificate { $certificate_path:
    ensure                        => present,
    private_key_path              => $private_key_path,
    common_name                   => $common_name,
    certificate_chain_path        => $certificate_chain_path,
    combine_certificate_and_chain => $combine_certificate_and_chain,
    alternate_names               => $alternate_names,
    generate_private_key          => $generate_private_key,
    contact                       => $_contact,
    directory                     => $_directory,
    agree_to_terms_url            => $_agree_to_terms_url,
    authorization_timeout         => $_authorization_timeout,
    renew_within_days             => $_renew_within_days,
    acme_private_key_path         => $_acme_private_key_path,
    # AWS-specific parameters for authorizing the domain
    aws_access_key_id             => $_aws_access_key_id,
    aws_secret_access_key         => $_aws_secret_access_key,
    route53_zone_id               => $_route53_zone_id,
  }

  file { $certificate_path:
    ensure  => file,
    owner   => $owner,
    group   => $group,
    mode    => $certificate_mode,
    require => Acme_certificate[$certificate_path],
  }

  if $certificate_chain_path {
    file { $certificate_chain_path:
      ensure  => file,
      owner   => $owner,
      group   => $group,
      mode    => $certificate_chain_mode,
      require => Acme_certificate[$certificate_path],
    }
  }

  if $generate_private_key {
    file { $private_key_path:
      ensure  => file,
      owner   => $owner,
      group   => $group,
      mode    => $private_key_mode,
      require => Acme_certificate[$certificate_path],
    }
  }
}
