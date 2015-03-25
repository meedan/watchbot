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

  test "should schedule checker for links up to 2 days old" do
    Delayed::Job.delete_all
    Time.stubs(:now).returns(Time.parse('2015-01-02 09:00:00'))
    link = create_link created_at: Time.parse('2015-01-01 09:00:00')
    job = link.delayed_job
    assert_equal Time.parse('2015-01-02 09:05:00').utc, job.run_at.utc
    Time.stubs(:now).returns(Time.parse('2015-01-02 09:07:00'))
    Delayed::Worker.new.work_off
    assert_equal Time.parse('2015-01-02 09:10:00').utc, job.reload.run_at.utc
  end

  test "should schedule checker for links up to 7 days old" do
    Delayed::Job.delete_all
    Time.stubs(:now).returns(Time.parse('2015-01-09 09:00:00'))
    link = create_link created_at: Time.parse('2015-01-03 09:00:00')
    job = link.delayed_job
    assert_equal Time.parse('2015-01-09 10:00:00').utc, job.run_at.utc
    Time.stubs(:now).returns(Time.parse('2015-01-09 10:02:00'))
    Delayed::Worker.new.work_off
    assert_equal Time.parse('2015-01-09 11:00:00').utc, job.reload.run_at.utc
  end

  test "should schedule checker for links more than 7 days old" do
    Delayed::Job.delete_all
    Time.stubs(:now).returns(Time.parse('2015-01-09 09:00:00'))
    link = create_link created_at: Time.parse('2015-01-01 09:00:00')
    job = link.delayed_job
    assert_equal Time.parse('2015-01-10 00:00:00').utc, job.run_at.utc
    Time.stubs(:now).returns(Time.parse('2015-01-10 10:02:00'))
    Delayed::Worker.new.work_off
    assert_equal Time.parse('2015-01-11 00:00:00').utc, job.reload.run_at.utc
  end

end
