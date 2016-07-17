# acme_certificates

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with acme_certificates](#setup)
    * [What acme_certificates affects](#what-acme_certificates-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with acme_certificates](#beginning-with-acme_certificates)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

Manages certificates on disk using an [ACME Certificate Authority](https://letsencrypt.github.io/acme-spec/) such as
[Let's Encrypt](https://letsencrypt.org/)

## Module Description

Requests certificates to be signed by an ACME Certificate Authority such as Let's Encrypt,
and automatically handles domain authorization.

Currently supports DNS domain authorization by creating DNS records in AWS Route 53.

## Setup

### What acme_certificates affects

* (Optionally) Installs the required `acme-client` and `aws-sdk` gems
* Registers an account with an ACME CA using the puppet agent's private key as the registration key
* Creates temporary records in AWS Route 53 to handle ACME domain authorization
* Generates CSRs based on new or existing private keys, and gets them signed by the ACME CA
* Writes the certificates and private keys to disk at a user-specified location

### Beginning with acme_certificates

```
# Set the defaults for all certificates
class { 'acme_certificates':
  # Automatically install the required ruby gems
  manage_gems        => true,

  # Let's Encrypt account contact details
  contact            => 'mailto:cert-admin@example.com',

  # Uncomment this to use the real Let's Encrypt server - this module defaults to the staging server
  # directory        => 'https://acme-v01.api.letsencrypt.org/directory',

  # Agree to the terms of service for Let's Encrypt -- read the terms before setting this parameter
  agree_to_terms_url => 'https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf',

  # The ID of an existing Route 53 zone to create DNS records under
  route53_zone_id    => 'ABC123',

  # If AWS credentials are not available via the standard environment variables, credentials files, or
  # EC2 instance profiles, they may be manually specified here or on acme_certificates::cert
  # aws_access_key_id     => 'MYACCESSKEYID',
  # aws_secret_access_key => 'SUPERSECRETVALUE',
}

# Get a signed certificate from the ACME CA
acme_certificates::cert { '/etc/ssl/certs/www.example.com.pem':
  private_key_path     => '/etc/ssl/private/www.example.com.key',
  common_name          => 'example.com',
  alternate_names      => ['www.example.com', 'web.example.com'],
  generate_private_key => true,
  owner                => nginx,
  group                => adm,
}
```

## Usage

Setup default values with the main `acme_certificates` class, then request certificates with the `acme_certificates::cert` type.

## Reference

### Classes

* [`acme_certificates`](#acme_certificates-1): Configures the default settings for certificates managed by this puppet module.
* [`acme_certificates::gems`](#acme_certificatesgems): Installs required gems for this module.

### Defines

* [`acme_certificates::cert`](#acme_certificatescert): Manage a certificate on disk signed by an ACME server.

### `acme_certificates`

Configures the default settings for certificates managed by this puppet module and optionally installs required gems.

#### Parameters

##### `manage_gems`
Whether to install the required ruby gems to make the custom providers of this puppet module work. Defaults to `false`.

If this is specified, the `acme_certificates::gems` class is automatically included.

##### `contact`
The contact information used to register with the ACME server.

e.g. 'mailto:cert-admin@example.com' or 'tel:+12025551212'

##### `directory`
The ACME server's directory URL. Defaults to the Let's Encrypt staging environment.

##### `agree_to_terms_url`
The URL of the terms of service of the ACME server to agree to. By setting this, you agree to the terms of service of the ACME server.

This must be set if the ACME server requires ACME clients to agree to terms of service.

##### `authorization_timeout`
The time, in seconds, to wait for the ACME server to process pending domain authorizations before timing out. Defaults to 5 minutes.

##### `aws_access_key_id`
The AWS Access Key ID to use to modify Route 53 records to authorize domains.

Defaults to no credentials (e.g. will use the AWS SDK default methods for finding credentials, or fail trying to look them up)

##### `aws_secret_access_key`
The AWS Secret Access Key to use to modify Route 53 records to authorize domains.

Defaults to no credentials (e.g. will use the AWS SDK default methods for finding credentials, or fail trying to look them up)

##### `route53_zone_id`
The Route 53 zone ID to create DNS records in to authorize domains.

### `acme_certificates::gems`

Installs required gems for this module. This is automatically included by the acme_certificates class if `manage_gems` is true.

#### Parameters

##### `gem_provider`
The package provider for intalling gems. Defaults to `'gem'`, the system gem provider.

### `acme_certificates::cert`

Manage a certificate on disk signed by an ACME server.

Automatically includes the `acme_certificates` class if it has not already been declared. Many parameters in this type can have their
default value specified in the `acme_certificates` class.

#### Parameters

##### `common_name`
The common name of the certificate.

##### `private_key_path`
The path to the private key file. If `generate_private_key` is not true, this file must already exist.

##### `certificate_path`
The file to place the signed certificate in. Defaults to the title

##### `certificate_chain_path`
The file to place the certificate chain in. Defaults to not writing the certificate chain to disk

##### `combine_certificate_and_chain`
Whether to write out the certificate and chain to the single file identified by certificate_path.
Defaults to not combining certificate and chain

##### `alternate_names`
Subject alternate names of the certificate. Defaults to no alternate names

##### `generate_private_key`
Whether to automatically generate a private key for this certificate. Defaults to not generating the private key

##### `owner`
The file owner for the generated certificate, certificate chain, and private key files. Defaults to `root`

##### `group`
The file group for the generated certificate, certificate chain, and private key files. Defaults to `root`

##### `certificate_mode`
The file mode for the generated certificate file. Defaults to `'0444'`

##### `certificate_chain_mode`
The file mode for the generated certificate chain file, if `$certificate_chain_path` is specified. Defaults to `'0444'`

##### `private_key_mode`
The file mode for the generated private key file, if `$generate_private_key` is `true`. Defaults to `'0400'`

##### `contact`
The contact information used to register with the ACME server.

e.g. 'mailto:cert-admin@example.com' or 'tel:+12025551212'

Defaults to the value from the `acme_certificates` class

##### `directory`
The ACME server's directory URL.

Defaults to the value from the `acme_certificates` class

##### `agree_to_terms_url`
The URL of the terms of service of the ACME server to agree to. By setting this, you agree to the terms of service of the ACME server.

This must be set (in the certificate resource or in the `acme_certificates` class) if the ACME server requires ACME clients to agree to
terms of service.

Defaults to the value from the `acme_certificates` class

##### `authorization_timeout`
The time, in seconds, to wait for the ACME server to process pending domain authorizations before timing out.

Defaults to the value from the `acme_certificates` class

##### `aws_access_key_id`
The AWS Access Key ID to use to modify Route 53 records to authorize the domain for this certificate.

Defaults to the value from the `acme_certificates` class

##### `aws_secret_access_key`
The AWS Secret Access Key to use to modify Route 53 records to authorize the domain for this certificate.

Defaults to the value from the `acme_certificates` class

##### `route53_zone_id`
The Route 53 zone ID to create DNS records in to authorize the domain for this certificate.

Defaults to the value from the `acme_certificates` class

## Limitations

Currently only supports handling the DNS-01 challenge by creating records in Route 53.

Tested on Ubuntu.

## Development

Fork and PR, but please provide tests and update the relevant documentation.
