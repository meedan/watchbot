ENV["RAILS_ENV"] ||= "test"
require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase

  def create_link(options = {})
    Link.create!({ url: random_url }.merge(options))
  end

  private

  def random_string(length = 10)
    (0...length).map { (65 + rand(26)).chr }.join
  end

  def random_url
    'http://' + random_string + '.' + random_string(3)
  end

end
