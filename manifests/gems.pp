# == Class: acme_certificates::gems
#
# Installs required gems for this module. This is automatically included by the acme_certificates class if manage_gems is true.
#
# === Parameters
#
# [*gem_provider*]
#   The package provider for intalling gems. Defaults to 'gem', the system gem provider.
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
class acme_certificates::gems($gem_provider = gem) {
  package { 'acme-client':
    ensure   => installed,
    provider => $gem_provider,
  }

  package { 'aws-sdk':
    ensure   => installed,
    provider => $gem_provider,
  }
}
