require 'openssl'

class Puppet::Provider::AcmeCertificate < Puppet::Provider

  def exists?
    Puppet.debug("Checking existence of #{resource[:certificate_path]}")
    if !File.exist? resource[:private_key_path]
      Puppet.debug("Private key #{resource[:private_key_path]} does not exist, so the certificate cannot be valid")
      false
    elsif !File.exist? resource[:certificate_path]
      Puppet.debug("Certificate #{resource[:certificate_path]} does not exist")
      false
    else
      cert = ::OpenSSL::X509::Certificate.new(File.read resource[:certificate_path])
      key = ::OpenSSL::PKey::RSA.new(File.read resource[:private_key_path])
      if cert.public_key.to_der != key.public_key.to_der
        Puppet.debug("Certificate #{resource[:certificate_path]} does not match private key #{resource[:private_key_path]}")
        false
      elsif cert.subject.to_s != csr.csr.subject.to_s
        Puppet.debug("Certificate #{resource[:certificate_path]} has subject '#{cert.subject}', expecting '#{csr.csr.subject}'")
        false
      elsif cert.not_after - resource[:renew_within_days] * 60 * 60 * 24 < Time.now
        Puppet.debug("Certificate #{resource[:certificate_path]} will expire at '#{cert.not_after}', which is within #{resource[:renew_within_days]} days")
        false
      else
        cert_alternate_names = cert.extensions.select {|e| e.oid == "subjectAltName"}.map { |e| e.value.split(',').map(&:strip) }.first || []
        csr_alternate_names = csr.names.map { |name| "DNS:#{name}" }
        if cert_alternate_names.sort != csr_alternate_names.sort
          Puppet.debug("Certificate #{resource[:certificate_path]} has alternative names #{cert_alternate_names}, but wanted #{csr_alternate_names}")
          false
        else
          true
        end
      end
    end
  end

  def create
    Puppet.debug("Creating certificate #{resource[:certificate_path]}")
    private_key_existed = File.exist? resource[:private_key_path]

    register_client
    authorize_domains

    cert = acme_client.new_certificate(csr)
    if resource[:generate_private_key] && !private_key_existed
      Puppet.debug("Writing private key to #{resource[:private_key_path]}")
      File.write(resource[:private_key_path], cert.request.private_key.to_pem)
    end

    cert_content = if resource[:combine_certificate_and_chain]
      cert.fullchain_to_pem
    else
      cert.to_pem
    end
    Puppet.debug("Writing certificate to #{resource[:certificate_path]}")
    File.write(resource[:certificate_path], cert_content)

    if resource[:certificate_chain_path]
      Puppet.debug("Writing certificate chain to #{resource[:certificate_chain_path]}")
      File.write(resource[:certificate_chain_path], cert.chain_to_pem)
    end
  end

  protected

  def handle_authorization(authorization)
    fail "Subclass hook handle_authorization not implemented"
  end

  def clean_authorization(authorization, challenge)
    fail "Subclass hook clean_authorization not implemented"
  end

  private

  def register_client
    begin
      registration = acme_client.register(contact: resource[:contact])
    rescue ::Acme::Client::Error::Malformed => e
      Puppet.debug("Error performing new registration, attempting to recover: #{e}")
      # Handling existing registrations not yet supported by acme-client, so poke at the internals a little :(
      # https://github.com/unixcharles/acme-client/issues/81
      env = acme_client.connection.app.env
      location = env.response_headers['location']
      if env.status == 409 && location
        Puppet.debug("Found existing registration for this private key at #{location}")
        # ACME spec says to POST an empty update at the resource to retrieve the registration
        response = acme_client.connection.post(location, { resource: 'reg' })
        # The reg resource returns the same data as the new-reg resource, but the Registration class expects a 'location' header...
        response.headers['location'] = location
        # Now hand it to acme-client's Registration class to parse
        registration = ::Acme::Client::Resources::Registration.new(acme_client, response)
      else
        fail "Unexpected error performing ACME registration: #{e.message}"
      end
    end
    terms_of_service_uri = registration && registration.term_of_service_uri
    if terms_of_service_uri
      if terms_of_service_uri == resource[:agree_to_terms_url]
        registration.agree_terms
      else
        fail "ACME Server requires you to agree to the terms of service at #{terms_of_service_uri}.\n" \
             'If you accept the terms, please set the agree_to_terms_url parameter to this URL'
      end
    end
  end

  def authorize_domains
    # TODO check if each domain is already authorized before going down the slow path of requesting it to be authorized
    [*resource[:alternate_names], resource[:common_name]].each do |domain|
      Puppet.debug("Authorizing domain '#{domain}'")
      authorization = acme_client.authorize(domain: domain)
      challenge = handle_authorization authorization
      begin
        challenge.request_verification
        begin
          Puppet.debug("Waiting for domain '#{domain}' to be authorized")
          Timeout::timeout(resource[:authorization_timeout]) do
            # TODO don't wait 5 minutes on invalid statuses
            while (status = challenge.verify_status) != 'valid'
              Puppet.debug("Domain '#{domain}' not yet authorized (#{status})")
              fail "Domain '#{domain}' has unexpected authorization status '#{status}'. Error: '#{challenge.error}'" if %w(invalid revoked).include? status
              sleep 1
            end
          end
        rescue Timeout::Error
          fail "Timed out waiting for ACME server to verify domain '#{domain}' after #{resource[:authorization_timeout]} seconds"
        end
      ensure
        clean_authorization authorization, challenge
      end
      Puppet.debug("Domain '#{domain}' successfully authorized")
    end
  end

  def acme_client
    @acme_client ||= ::Acme::Client.new(private_key: acme_private_key, directory_uri: resource[:directory], endpoint: endpoint)
  end

  # TODO this annoys me, should not be necessary
  def endpoint
    URI.join(resource[:directory], "/").to_s
  end

  def csr
    @csr ||= begin
      csr_params = {
        common_name: resource[:common_name],
        names: resource[:alternate_names],
      }
      if File.exist? resource[:private_key_path]
        csr_params[:private_key] = ::OpenSSL::PKey::RSA.new(File.read resource[:private_key_path])
      elsif !resource[:generate_private_key]
        fail "Could not generate certificate #{resource[:certificate_path]}: private key #{resource[:private_key_path]} does not exist"
      end

      ::Acme::Client::CertificateRequest.new(csr_params)
    end
  end

  # Get the private key to use with the ACME client.
  def acme_private_key
    ::OpenSSL::PKey::RSA.new(File.read(acme_private_key_path))
  rescue => e
    fail "Could not load puppet private key from #{acme_private_key_path} to register with ACME server: #{e}"
  end

  # Path to the private key to use with the ACME client. Defaults to the puppet agent's private key.
  def acme_private_key_path
    if resource[:acme_private_key_path].nil? || resource[:acme_private_key_path].empty?
      Puppet[:hostprivkey]
    else
      resource[:acme_private_key_path]
    end
  end
end
