# == Class: acme_certificates::gems
#
# Installs required gems for this module. This is automatically included by the acme_certificates class if manage_gems is true.
#
# === Parameters
#
# [*gem_provider*]
#   The package provider for intalling gems. Defaults to 'gem', the system gem provider.
#
# [*acme_client_version*]
#   The version of the acme-client gem to install. Defaults to '~> 2.0', to install the latest 2.x version. This must install a
#   compatible version of the library -- currently only 2.x is compatible.
#
# === Examples
#
#  class { 'acme_certificates::gems':
#    gem_provider => puppet_gem,
#  }
#
# === Copyright
#
# Copyright 2016 Nicholas Hinds, unless otherwise noted.
#
class acme_certificates::gems(
  $gem_provider        = gem,
  $acme_client_version = '~> 2.0',
) {
  package { 'acme-client':
    ensure   => $acme_client_version,
    provider => $gem_provider,
  }

  package { 'aws-sdk':
    ensure   => installed,
    provider => $gem_provider,
  }
}
