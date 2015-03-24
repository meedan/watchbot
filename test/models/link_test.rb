require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class LinkTest < ActiveSupport::TestCase

  test "should create link" do
    assert_difference 'Link.count' do
      create_link
    end
  end

  test "should not create link without URL" do
    assert_no_difference 'Link.count' do
      assert_raises Mongoid::Errors::Validations do
        create_link url: nil
      end
    end
  end

  test "should not create link with invalid URL" do
    assert_no_difference 'Link.count' do
      assert_raises Mongoid::Errors::Validations do
        create_link url: 'test'
      end
    end
  end

end
