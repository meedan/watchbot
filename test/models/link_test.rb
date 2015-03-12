require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class LinkTest < ActiveSupport::TestCase

  test "should create link" do
    assert_difference 'Link.count' do
      create_link
    end
  end

end
