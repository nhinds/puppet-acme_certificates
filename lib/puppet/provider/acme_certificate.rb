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
    order = authorize_domains
    finalize(order)

    certificate, chain = order.certificate.split(/(?<=-----END CERTIFICATE-----)/, 2).map(&:strip)
    if resource.generate_private_key? && !private_key_existed
      Puppet.debug("Writing private key to #{resource[:private_key_path]}")
      File.write(resource[:private_key_path], csr.private_key.to_pem, perm: resource[:private_key_mode])
    end

    cert_content = if resource.combine_certificate_and_chain?
      "#{certificate}\n#{chain}"
    else
      certificate
    end
    Puppet.debug("Writing certificate to #{resource[:certificate_path]}")
    File.write(resource[:certificate_path], cert_content, perm: resource[:certificate_mode])

    if resource[:certificate_chain_path]
      Puppet.debug("Writing certificate chain to #{resource[:certificate_chain_path]}")
      File.write(resource[:certificate_chain_path], chain, resource[:certificate_chain_mode])
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
    terms_of_service_uri = acme_client.terms_of_service
    if terms_of_service_uri
      if terms_of_service_uri == resource[:agree_to_terms_url]
        terms_of_service_agreed = true
      else
        fail "ACME Server requires you to agree to the terms of service at #{terms_of_service_uri}.\n" \
             'If you accept the terms, please set the agree_to_terms_url parameter to this URL'
      end
    end

    acme_client.new_account(contact: resource[:contact], terms_of_service_agreed: terms_of_service_agreed)
  end

  def authorize_domains
    acme_client.new_order(identifiers: csr.names).tap do |order|
      challenges = order.authorizations.map do |auth|
        next if auth.status == 'valid'
        Puppet.debug("Authorizing domain '#{auth.domain}'")
        challenge = handle_authorization auth
        begin
          challenge.request_validation
          begin
            Puppet.debug("Waiting for domain '#{auth.domain}' to be authorized")
            Timeout::timeout(resource[:authorization_timeout]) do
              wait_while(challenge, %w(pending processing), "Domain '#{auth.domain}' not yet authorized")
              fail "Domain '#{auth.domain}' has unexpected authorization status '#{challenge.status}'. Error: '#{challenge.error}'" unless challenge.status == 'valid'
              auth.reload
              wait_while(auth, %w(pending processing), "Authorization for domain '#{auth.domain}' is not yet valid")
              fail "Authorization for domain '#{auth.domain}' has unexpected status '#{auth.status}'" unless auth.status == 'valid'
            end
          rescue Timeout::Error
            fail "Timed out waiting for ACME server to verify domain '#{auth.domain}' after #{resource[:authorization_timeout]} seconds"
          end
        ensure
          clean_authorization auth, challenge
        end
        Puppet.debug("Domain '#{auth.domain}' successfully authorized")
      end
    end
  end

  def finalize(order)
    order.finalize(csr: csr)
    begin
      Puppet.debug("Waiting for order to be finalized for #{csr.names}")
      Timeout::timeout(resource[:order_timeout]) do
        wait_while(order, %w(pending processing), "Order for #{csr.names} is still processing")
        fail "Order for #{csr.names} has unexpected status '#{order.status}'" unless order.status == 'valid'
      end
    rescue Timeout::Error
      fail "Timed out waiting for ACME server to finalize order for #{csr.names} after #{resource[:authorization_timeout]} seconds"
    end
  end

  def wait_while(obj, statuses, msg)
    while statuses.include? obj.status
      Puppet.debug msg
      sleep 1
      obj.reload
    end
  end

  def acme_client
    @acme_client ||= ::Acme::Client.new(private_key: acme_private_key, directory: resource[:directory])
  end

  def csr
    @csr ||= begin
      csr_params = {
        common_name: resource[:common_name],
        names: Array(resource[:alternate_names]),
      }
      if File.exist? resource[:private_key_path]
        csr_params[:private_key] = ::OpenSSL::PKey::RSA.new(File.read resource[:private_key_path])
      elsif !resource.generate_private_key?
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
