require 'spec_helper'
describe 'acme_certificates::gems' do

  context 'with defaults for all parameters' do
    it { should contain_package('acme-client').with_ensure('~> 2.0').with_provider('gem') }
    it { should contain_package('aws-sdk').with_provider('gem') }
  end

  context 'with gem_provider' do
    let(:params) { { gem_provider: 'puppet_gem' } }

    it { should contain_package('acme-client').with_provider('puppet_gem') }
    it { should contain_package('aws-sdk').with_provider('puppet_gem') }
  end

  context 'with acme_client_version' do
    let(:params) { { acme_client_version: '2.0.0' } }

    it { should contain_package('acme-client').with_ensure('2.0.0') }
  end
end
