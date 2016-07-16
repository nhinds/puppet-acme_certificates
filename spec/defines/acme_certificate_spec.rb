require 'spec_helper'
describe 'acme_certificate' do
  let(:pre_condition) { 'include acme_certificates' }
  let(:title) { '/tmp/temporary.crt' }
  let(:params) do
    { private_key_path: '/tmp/private.key' }
  end

  it { should compile }
  it { should contain_acme_certificate('/tmp/temporary.crt') }

  context 'with a private key in the catalog' do
    let(:pre_condition) { 'file { "/tmp/private.key": ensure => file }'}

    it { should contain_acme_certificate('/tmp/temporary.crt').that_requires('File[/tmp/private.key]') }
  end
end
