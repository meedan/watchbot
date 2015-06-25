require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class LinkTest < ActiveSupport::TestCase

  def setup
    super
    Link.destroy_all
  end

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
    assert_equal Time.parse('2015-01-10 01:00:00').utc, job.run_at.utc
    Time.stubs(:now).returns(Time.parse('2015-01-10 10:02:00'))
    Delayed::Worker.new.work_off
    assert_equal Time.parse('2015-01-11 01:00:00').utc, job.reload.run_at.utc
  end

  test "should stop checker" do
    stubs_config({ 'schedule' => [{ 'to' => 172800, 'interval' => '*/5 * * * *' }] })
    Delayed::Job.delete_all
    Time.stubs(:now).returns(Time.parse('2015-01-02 09:00:00'))
    link = create_link created_at: Time.parse('2015-01-01 09:00:00')
    job = link.delayed_job
    assert_equal Time.parse('2015-01-02 09:05:00').utc, job.run_at.utc
    Time.stubs(:now).returns(Time.parse('2015-01-10 10:00:00'))
    assert_difference 'Delayed::Job.count', -1 do
      Delayed::Worker.new.work_off
    end
    assert_raises Mongoid::Errors::DocumentNotFound do
      job.reload
    end
  end

  test "should check that URL is offline if domain is invalid" do
    link = create_link url: 'http://thisisnotonline.com'
    assert link.check404
    assert_equal 404, link.reload.status
  end

  test "should check that URL is offline" do
    link = create_link url: 'http://meedan.org/404'
    assert link.check404
    assert_equal 404, link.reload.status
  end

  test "should check that URL is offline if forbidden" do
    Net::HTTPNotFound.any_instance.stubs(:code).returns(403)
    link = create_link url: 'http://meedan.org/403'
    assert link.check404
    assert_equal 403, link.reload.status
  end

  test "should check that URL is online" do
    link = create_link url: 'http://www.google.com'
    assert !link.check404
    assert_equal 200, link.reload.status
  end

  test "should check that HTTPS URL is online" do
    link = create_link url: 'https://www.google.com'
    assert !link.check404
    assert_equal 200, link.reload.status
  end

  test "should have status" do
    link = create_link
    assert_kind_of Integer, link.status
    link.status = 200
    link.save!
    assert_equal 200, link.reload.status
  end

  test "should only accept numbers for status" do
    assert_no_difference 'Link.count' do
      assert_raises Mongoid::Errors::Validations do
        create_link status: 'not number'
      end
    end
  end

  test "should not accept duplicated URLs" do
    assert_difference 'Link.count' do
      assert_nothing_raised do
        create_link url: 'http://test.com/same'
      end
    end
    assert_no_difference 'Link.count' do
      assert_raises Mongoid::Errors::Validations do
        create_link url: 'http://test.com/same'
      end
    end
  end
  
  test "should run checkers and not remove link if not applicable" do
    stubs_config({ 'conditions' => [{ 'linkRegex' => '^https?:\/\/(www\.)?(twitter|instagram)\.com\/', 'condition' => 'check404', 'removeIfApplies' => false }]})
    link = create_link url: 'https://twitter.com/caiosba/status/549403744430215169', status: 200
    assert_no_difference 'Link.count' do
      link.check
    end
    assert_equal 404, link.reload.status
  end

  test "should run checkers and remove link if applicable" do
    stubs_config({ 'conditions' => [{ 'linkRegex' => '^https?:\/\/(www\.)?(twitter|instagram)\.com\/', 'condition' => 'check404', 'removeIfApplies' => true }]})
    link = create_link url: 'https://twitter.com/caiosba/status/549403744430215169', status: 200
    assert_difference 'Link.count', -1 do
      link.check
    end
  end

  test "should create link without status" do
    assert_difference 'Link.count' do
      create_link status: nil
    end
  end

  test "should notify if condition is verified" do
    Link.any_instance.expects(:notify).once
    link = create_link url: 'https://twitter.com/caiosba/status/549403744430215169'
    link.check
  end

  test "should not notify if condition is not verified" do
    Link.any_instance.expects(:notify).never
    link = create_link url: 'https://twitter.com/caiosba/status/539790133219053568'
    link.check
  end

  test "should generate a notification signature" do
    link = create_link
    assert_kind_of String, link.notification_signature('{}')
  end

  test "should notify client" do
    link = create_link
    response = link.notify({})
    assert_kind_of Net::HTTPResponse, response
  end

  test "should get job" do
    link = create_link
    assert_equal link.delayed_job, link.job
  end

  test "should run checker for Google Spreadsheet" do
    Link.any_instance.expects(:check404).never
    Link.any_instance.expects(:check_google_spreadsheet_updated).once
    link = create_link url: 'https://docs.google.com/a/meedan.net/spreadsheets/d/1qpLfypUaoQalem6i3SHIiPqHOYGCWf2r7GFbvkIZtvk/edit?usp=docslist_api#test'
    link.check
  end

  test "should check that Google Spreadsheet was not updated if someone is editing" do
    link = create_link url: 'https://docs.google.com/a/meedan.net/spreadsheets/d/1qpLfypUaoQalem6i3SHIiPqHOYGCWf2r7GFbvkIZtvk/edit?usp=docslist_api#test'
    resp = nil
    t = Thread.new{ resp = link.check_google_spreadsheet_updated }
    sleep 20
    w = link.get_google_worksheet
    w[5, 3] = 'Changed'
    w.save
    t.join
    assert_not_nil resp
    assert !resp
    w[5, 3] = 'Not Found'
    w.save
  end

  test "should check that Google Spreadsheet was not updated if nothing changed" do
    link = create_link url: 'https://docs.google.com/a/meedan.net/spreadsheets/d/1qpLfypUaoQalem6i3SHIiPqHOYGCWf2r7GFbvkIZtvk/edit?usp=docslist_api#test'
    resp = link.check_google_spreadsheet_updated
    resp = link.check_google_spreadsheet_updated
    assert !resp
  end

  test "should check that Google Spreadsheet was updated" do
    link = create_link url: 'https://docs.google.com/a/meedan.net/spreadsheets/d/1qpLfypUaoQalem6i3SHIiPqHOYGCWf2r7GFbvkIZtvk/edit?usp=docslist_api#test'
    resp = link.check_google_spreadsheet_updated
    w = link.get_google_worksheet
    w[5, 3] = 'Changed'
    w.save
    resp = link.check_google_spreadsheet_updated
    assert resp
    w[5, 3] = 'Not Found'
    w.save
  end

  test "should have data" do
    link = create_link
    assert_equal({}, link.data)
    link.data[:foo] = 'bar'
    link.save!
    assert_equal({ 'foo' => 'bar' }, link.reload.data)
  end

  test "should get access token" do
    Rails.cache.delete('!google_access_token')
    link = create_link
    assert_kind_of String, link.send(:generate_google_access_token)
  end

  test "should ask for access token" do
    Rails.cache.delete('!google_access_token')
    link = create_link url: 'https://docs.google.com/a/meedan.net/spreadsheets/d/1qpLfypUaoQalem6i3SHIiPqHOYGCWf2r7GFbvkIZtvk/edit?usp=docslist_api#test'
    assert_nothing_raised do
      link.get_google_worksheet
    end
  end

  test "should refresh token" do
    Rails.cache.expects(:fetch).returns('invalid token')
    link = create_link url: 'https://docs.google.com/a/meedan.net/spreadsheets/d/1qpLfypUaoQalem6i3SHIiPqHOYGCWf2r7GFbvkIZtvk/edit?usp=docslist_api#test'
    assert_nothing_raised do
      link.get_google_worksheet
    end
  end

  test "should not crash if payload object was removed" do
    stubs_config({ 'conditions' => [{ 'linkRegex' => '^https?:\/\/(www\.)?(twitter|instagram)\.com\/', 'condition' => 'check404', 'removeIfApplies' => true }]})
    link = create_link url: 'https://twitter.com/caiosba/status/549403744430215169', status: 200
    job = link.job
    Time.stubs(:now).returns(link.created_at.since(5.minutes))
    assert_nothing_raised do
      Delayed::Worker.new.work_off
    end
  end
end
