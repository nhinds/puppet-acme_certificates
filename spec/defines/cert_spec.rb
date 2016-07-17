require 'spec_helper'
describe 'acme_certificates::cert' do
  let(:title) { '/tmp/temporary.crt' }
  let(:params) do
    {
      private_key_path: '/tmp/private.key',
      common_name: 'temporary.example.com',
      contact: 'mailto:admin@example.com'
    }
  end

  it { should compile }
  it 'should pass parameters to acme_certificate' do
    should contain_acme_certificate('/tmp/temporary.crt')
      .with_private_key_path('/tmp/private.key')
      .with_common_name('temporary.example.com')
  end
  it 'should manage the certificate after generating it' do
    should contain_file('/tmp/temporary.crt')
      .that_requires('Acme_certificate[/tmp/temporary.crt]')
      .with_owner('root')
      .with_group('root')
      .with_mode('0444')
  end

  context 'with certificate owner and mode defined' do
    let(:params) { super().merge(owner: 'nginx', group: 'adm', certificate_mode: '0440') }

    it 'should manage certificate owner and mode' do
      should contain_file('/tmp/temporary.crt')
        .with_owner('nginx')
        .with_group('adm')
        .with_mode('0440')
    end
  end

  context 'with a private key in the catalog' do
    let(:pre_condition) { 'file { "/tmp/private.key": ensure => file }'}

    it 'should require the private key' do
      should contain_acme_certificate('/tmp/temporary.crt').that_requires('File[/tmp/private.key]')
    end
  end

  context 'when generating the private key' do
    let(:params) { super().merge(generate_private_key: true) }

    it 'should manage the private key after generating it' do
      should contain_file('/tmp/private.key').that_requires('Acme_certificate[/tmp/temporary.crt]')
    end

    context 'with private key owner and mode defined' do
      let(:params) { super().merge(owner: 'bob', group: 'admins', private_key_mode: '0500') }

      it 'should manage private key owner and mode' do
        should contain_file('/tmp/private.key')
          .with_owner('bob')
          .with_group('admins')
          .with_mode('0500')
      end
    end
  end

  context 'when writing the certificate chain separately' do
    let(:params) { super().merge(certificate_chain_path: '/opt/intermediates.pem') }

    it 'should manage the certificate chain after generating it' do
      should contain_file('/opt/intermediates.pem').that_requires('Acme_certificate[/tmp/temporary.crt]')
    end

    context 'with certificate chain owner and mode defined' do
      let(:params) { super().merge(owner: 'www-data', group: 'adm', certificate_chain_mode: '0554') }

      it 'should manage certificate chain owner and mode' do
        should contain_file('/opt/intermediates.pem')
          .with_owner('www-data')
          .with_group('adm')
          .with_mode('0554')
      end
    end
  end

  context 'when contact is not specified on the certificate' do
    let(:params) { super().reject { |k, _| k == :contact } }

    context 'when contact is not specified on acme_certificates' do
      it { should compile.and_raise_error(/Must specify `contact`/)}
    end

    context 'when contact is specified on acme_certificates' do
      let(:pre_condition) { 'class { acme_certificates: contact => "mailto:admin@example.org" }' }

      it 'should use the values from acme_certificates' do
        should contain_acme_certificate('/tmp/temporary.crt').with_contact('mailto:admin@example.org')
      end
    end
  end

  {
    directory:{
      default: 'https://acme-staging.api.letsencrypt.org/directory',
      override: 'https://acme-v01.api.letsencrypt.org/directory'
    },
    authorization_timeout: {
      default: 300,
      override: 600
    }
  }.each do |param, options|
    context "when #{param} is specified" do
      let(:params) { super().merge(param => options[:override]) }

      it { should contain_acme_certificate('/tmp/temporary.crt').with(param => options[:override]) }
    end

    context "when #{param} is not specified on the certificate" do
      let(:params) { super().reject { |k, _| k == param } }

      context "when #{param} is not specified on acme_certificates" do
        it 'should use the default values from acme_certificates' do
          should contain_acme_certificate('/tmp/temporary.crt').with(param => options[:default])
        end
      end

      context "when #{param} is specified on acme_certificates" do
        let(:pre_condition) { "class { acme_certificates: #{param} => #{options[:override].inspect} }" }

        it 'should use the values from acme_certificates' do
          should contain_acme_certificate('/tmp/temporary.crt').with(param => options[:override])
        end
      end
    end
  end

  %w(agree_to_terms_url aws_access_key_id aws_secret_access_key route53_zone_id).each do |param|
    context "when #{param} is specified" do
      let(:params) { super().merge(param => 'something') }

      it { should contain_acme_certificate('/tmp/temporary.crt').with(param => 'something') }
    end

    context "when #{param} is not specified on the certificate" do
      let(:params) { super().reject { |k, _| k == param } }

      context "when #{param} is not specified on acme_certificates" do
        it 'should pass an empty value to acme_certificate' do
          should contain_acme_certificate('/tmp/temporary.crt').with(param => '')
        end
      end

      context "when #{param} is specified on acme_certificates" do
        let(:pre_condition) { "class { acme_certificates: #{param} => 'global something' }" }

        it 'should use the values from acme_certificates' do
          should contain_acme_certificate('/tmp/temporary.crt').with(param => 'global something')
        end
      end
    end
  end
end
