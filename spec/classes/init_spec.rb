require 'spec_helper'
describe 'acme_certificates' do

  context 'with defaults for all parameters' do
    it { should contain_class('acme_certificates') }
  end
end
