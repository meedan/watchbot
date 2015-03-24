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

  test "should start watching when link is created" do
    link = nil
    assert_difference 'Delayed::Job.count' do
      link = create_link
    end
    assert_kind_of Delayed::Job, link.delayed_job
  end

  test "should not create link without job" do
    Delayed::Job.expects(:enqueue).returns(nil)
    assert_no_difference 'Link.count' do
      assert_raises Mongoid::Errors::Validations do
        create_link
      end
    end
  end

  test "should destroy job when link is destroyed" do
    link = create_link
    assert_difference 'Delayed::Job.count', -1 do
      link.destroy!
    end
  end

  test "should not destroy link when job is destroyed" do
    link = create_link
    assert_no_difference 'Link.count' do
      link.delayed_job.destroy!
    end
  end

end
