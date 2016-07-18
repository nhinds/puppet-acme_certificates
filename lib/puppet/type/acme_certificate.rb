require 'puppet/parameter/boolean'

Puppet::Type.newtype(:acme_certificate) do
  @doc = 'Request a signed certificate from an ACME CA.'

  ensurable

  newparam(:certificate_path, namevar: true)
  newparam(:certificate_chain_path)
  newparam(:combine_certificate_and_chain, boolean: true, parent: Puppet::Parameter::Boolean)

  newparam(:common_name)
  newparam(:alternate_names)
  newparam(:private_key_path)
  newparam(:generate_private_key, boolean: true, parent: Puppet::Parameter::Boolean)

  newparam(:certificate_mode) do
    validate do |value|
      # Verify this value is a valid octal string
      Integer(value, 8)
    end

    munge do |value|
      Integer(value, 8)
    end
  end
  newparam(:certificate_chain_mode) do
    validate do |value|
      # Verify this value is a valid octal string
      Integer(value, 8)
    end

    munge do |value|
      Integer(value, 8)
    end
  end
  newparam(:private_key_mode) do
    validate do |value|
      # Verify this value is a valid octal string
      Integer(value, 8)
    end

    munge do |value|
      Integer(value, 8)
    end
  end

  newparam(:contact)
  newparam(:directory)
  newparam(:agree_to_terms_url)

  newparam(:authorization_timeout) do
    munge do |value|
      Integer(value)
    end
  end
  newparam(:renew_within_days) do
    munge do |value|
      Integer(value)
    end
  end
  newparam(:acme_private_key_path)

  newparam(:aws_access_key_id)
  newparam(:aws_secret_access_key)
  newparam(:route53_zone_id)

  autorequire(:file) do
    files = []
    files << self[:private_key_path] unless self[:generate_private_key]
    files << self[:acme_private_key_path] unless self[:acme_private_key_path].nil? || self[:acme_private_key_path].empty?
    files
  end
end
