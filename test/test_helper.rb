ENV["RAILS_ENV"] ||= "test"
require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'webmock/test_unit'

class ActiveSupport::TestCase

  def setup
    WebMock.disable_net_connect! allow: ['codeclimate.com', /^http:\/\/test\./, /meedan/, 'thisisnotonline.com', /www\.google\.com/,
                                         'graph.facebook.com', 'twitter.com', 'docs.google.com', 'spreadsheets.google.com',
                                         'accounts.google.com', 'www.googleapis.com', 'api.twitter.com', /facebook\.com/]
    WebMock.stub_request(:post, 'http://localhost:4567/payload')
  end

  def create_link(options = {})
    link = Link.create!({ url: random_url, status: 100, application: 'test' }.merge(options))
    link.created_at = options[:created_at] if options.has_key?(:created_at)
    link.save!
    link.reload
  end

  def create_api_key(options = {})
    ApiKey.create!({ application: 'test' }.merge(options))
  end

  def stubs_config(overwrite = {})
    WATCHBOT_CONFIG['test'].each do |key, value|
      Link.any_instance.stubs(:get_config).with(key).returns(value)
    end
    overwrite.each do |key, value|
      Link.any_instance.stubs(:get_config).with(key).returns(value)
    end
  end

  def authorize(api_key = nil)
    api_key ||= create_api_key
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials(api_key.access_token)
  end

  private

  def random_string(length = 10)
    (0...length).map { (65 + rand(26)).chr }.join
  end

  def random_url
    'http://test.' + random_string + '.' + random_string(3)
  end

end
