require 'spec_helper'
describe 'acme_certificates' do

  context 'with defaults for all parameters' do
    it { should contain_class('acme_certificates') }
    it { should_not contain_class('acme_certificates::gems') }
  end

  context 'with manage_gems' do
    let(:params) { { manage_gems: true } }

    it { should contain_class('acme_certificates::gems') }
  end
end
