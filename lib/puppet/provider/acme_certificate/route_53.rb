require_relative '../acme_certificate'

Puppet::Type.type(:acme_certificate).provide(:route_53, :parent => Puppet::Provider::AcmeCertificate) do
  desc 'ACME certificate provider which performs dns-01 verification via Route 53 DNS records'

  confine feature: :acme_client
  confine feature: :aws_sdk

  has_features :uses_aws_sdk, :route_53

  protected

  def handle_authorization(authorization)
    fail "Missing parameter route53_zone_id" unless resource[:route53_zone_id] && !resource[:route53_zone_id].empty?

    authorization.dns01.tap do |challenge|
      upsert = change 'UPSERT', authorization, challenge
      Puppet.debug("Creating DNS record in Route 53 zone '#{resource[:route53_zone_id]}': #{upsert}")
      change_info = route53.change_resource_record_sets(hosted_zone_id: resource[:route53_zone_id], change_batch: { changes: [upsert] })
      Puppet.debug('Waiting for changes to propagate to Route 53 DNS servers')
      route53.wait_until(:resource_record_sets_changed, id: change_info.change_info.id) do |w|
        # Wait for up to 5 minutes, checking every 5 seconds
        w.max_attempts = 60
        w.delay = 5
        w.before_wait do |attempts, response|
          Puppet.debug("Route 53 changes not yet propagated, waiting (#{attempts}/60)")
        end
      end
    end
  end

  def clean_authorization(authorization, challenge)
    delete = change 'DELETE', authorization, challenge
    Puppet.debug("Removing DNS record from Route 53 zone '#{resource[:route53_zone_id]}': #{delete}")
    route53.change_resource_record_sets(hosted_zone_id: resource[:route53_zone_id], change_batch: { changes: [delete] })
  end

  private

  def route53
    @route53 ||= ::Aws::Route53::Client.new(route53_configuration)
  end

  def route53_configuration
    # Route53 is not region-specific, but the client blows up if we don't give it one
    config = { region: 'us-east-1' }
    if resource[:aws_access_key_id] && !resource[:aws_access_key_id].empty?
      config[:credentials] = ::Aws::Credentials.new(resource[:aws_access_key_id], resource[:aws_secret_access_key])
    end
    config
  end

  def change(action, authorization, challenge)
    {
      action: action,
      resource_record_set: {
        name: "#{challenge.record_name}.#{authorization.domain}",
        type: challenge.record_type,
        ttl: 60,
        resource_records: [ { value: %Q("#{challenge.record_content}") } ]
      }
    }
  end
end
