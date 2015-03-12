ENV["RAILS_ENV"] ||= "test"
require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
end
