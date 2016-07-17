Puppet::Type.newtype(:acme_certificate) do
  @doc = 'Request a signed certificate from an ACME CA.'

  ensurable

  newparam(:certificate_path, namevar: true)
  newparam(:certificate_chain_path)
  newparam(:combine_certificate_and_chain)

  newparam(:common_name)
  newparam(:alternate_names)
  newparam(:private_key_path)
  newparam(:generate_private_key)

  newparam(:contact)
  newparam(:directory)
  newparam(:agree_to_terms_url)

  newparam(:authorization_timeout)

  newparam(:aws_access_key_id)
  newparam(:aws_secret_access_key)
  newparam(:route53_zone_id)

  autorequire(:file) do
    self[:private_key_path] unless self[:generate_private_key]
  end
end
