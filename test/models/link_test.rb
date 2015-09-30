require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'watchbot_memory'

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
    assert_equal 0, Sidekiq::Cron::Job.count
    link = create_link
    assert_equal 1, Sidekiq::Cron::Job.count
    assert_kind_of Sidekiq::Cron::Job, link.job
  end

  test "should destroy job when link is destroyed" do
    assert_equal 0, Sidekiq::Cron::Job.count
    link = create_link
    assert_equal 1, Sidekiq::Cron::Job.count
    link.destroy
    assert_equal 0, Sidekiq::Cron::Job.count
  end

  test "should not destroy link when job is destroyed" do
    link = create_link
    assert_equal 1, Sidekiq::Cron::Job.count
    assert_no_difference 'Link.count' do
      link.job.destroy
    end
    assert_equal 0, Sidekiq::Cron::Job.count
  end

  test "should schedule checker for links up to 2 days old" do
    Time.stubs(:now).returns(Time.parse('2015-01-02 09:00:00'))

    t = Time.parse('2015-01-01 09:00:00')
    link = create_link created_at: t

    t = Time.parse('2015-01-02 09:01:00')
    assert_equal Time.parse('2015-01-02 09:00:00'), link.reload.job.last_time(t)

    t = Time.parse('2015-01-02 09:04:00')
    assert_equal Time.parse('2015-01-02 09:00:00'), link.reload.job.last_time(t)

    t = Time.parse('2015-01-02 09:06:00')
    assert_equal Time.parse('2015-01-02 09:05:00'), link.reload.job.last_time(t)

    Time.unstub(:now)
  end

  test "should schedule checker for links up to 7 days old" do
    Time.stubs(:now).returns(Time.parse('2015-01-05 09:00:00'))

    t = Time.parse('2015-01-01 09:00:00')
    link = create_link created_at: t

    t = Time.parse('2015-01-05 09:01:00')
    assert_equal Time.parse('2015-01-05 09:00:00'), link.reload.job.last_time(t)

    t = Time.parse('2015-01-05 09:30:00')
    assert_equal Time.parse('2015-01-05 09:00:00'), link.reload.job.last_time(t)

    t = Time.parse('2015-01-05 10:01:00')
    assert_equal Time.parse('2015-01-05 10:00:00'), link.reload.job.last_time(t)
    
    Time.unstub(:now)
  end

  test "should schedule checker for links more than 7 days old" do
    Time.stubs(:now).returns(Time.parse('2015-01-10 09:00:00'))

    t = Time.parse('2015-01-01 09:00:00')
    link = create_link created_at: t

    t = Time.parse('2015-01-10 09:01:00')
    assert_equal Time.parse('2015-01-10 03:00:00'), link.reload.job.last_time(t)

    t = Time.parse('2015-01-10 09:30:00')
    assert_equal Time.parse('2015-01-10 03:00:00'), link.reload.job.last_time(t)

    t = Time.parse('2015-01-10 10:01:00')
    assert_equal Time.parse('2015-01-10 03:00:00'), link.reload.job.last_time(t)

    t = Time.parse('2015-01-11 10:01:00')
    assert_equal Time.parse('2015-01-11 03:00:00'), link.reload.job.last_time(t)
    
    Time.unstub(:now)
  end

  test "should stop checker" do
    stubs_config({ 'schedule' => [{ 'to' => 172800, 'interval' => '*/5 * * * *' }] })
    
    Time.stubs(:now).returns(Time.parse('2015-01-02 09:00:00'))
    t = Time.parse('2015-01-01 09:00:00')
    link = create_link created_at: t
    assert_not_nil link.job

    Time.stubs(:now).returns(Time.parse('2015-01-05 09:00:00'))
    t = Time.parse('2015-01-01 09:00:00')
    link = create_link created_at: t
    assert_nil link.job
    
    Time.unstub(:now)
  end

  test "should check that URL is offline if domain is invalid" do
    link = create_link url: 'http://thisisnotonline.com'
    assert link.check404
    assert_equal 404, link.status
  end

  test "should check that URL is offline" do
    link = create_link url: 'http://meedan.org/404'
    assert link.check404
    assert_equal 404, link.status
  end

  test "should check that URL is offline if forbidden" do
    Net::HTTPNotFound.any_instance.stubs(:code).returns(403)
    link = create_link url: 'http://meedan.org/403'
    assert link.check404
    assert_equal 403, link.status
    Net::HTTPNotFound.any_instance.unstub(:code)
  end

  test "should check that URL is online" do
    link = create_link url: 'http://www.google.com'
    assert !link.check404
    assert_equal 302, link.status
  end

  test "should check that HTTPS URL is online" do
    link = create_link url: 'https://www.google.com'
    assert !link.check404
    assert_equal 200, link.status
  end

  test "should have status" do
    link = create_link
    assert_kind_of Integer, link.status
    link.status = 200
    link.save!
    assert_equal 200, link.status
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
    Link.any_instance.unstub(:notify)
  end

  test "should not notify if condition is not verified" do
    Link.any_instance.expects(:notify).once
    link = create_link url: 'https://twitter.com/caiosba/status/539790133219053568'
    link.check
    Link.any_instance.unstub(:notify)
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
    assert_not_nil link.job
  end

  test "should run checker for Google Spreadsheet" do
    Link.any_instance.expects(:check404).never
    Link.any_instance.expects(:check_google_spreadsheet_updated).once
    link = create_link url: 'https://docs.google.com/a/meedan.net/spreadsheets/d/1qpLfypUaoQalem6i3SHIiPqHOYGCWf2r7GFbvkIZtvk/edit?usp=docslist_api#test'
    link.check
    Link.any_instance.unstub(:check404)
    Link.any_instance.unstub(:check_google_spreadsheet_updated)
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
    Rails.cache.unstub(:fetch)
  end

  test "should not crash if payload object was removed" do
    stubs_config({ 'conditions' => [{ 'linkRegex' => '^https?:\/\/(www\.)?(twitter|instagram)\.com\/', 'condition' => 'check404', 'removeIfApplies' => true }]})
    link = create_link url: 'https://twitter.com/caiosba/status/549403744430215169', status: 200
    job = link.job
    Time.stubs(:now).returns(link.created_at.since(5.minutes))
    assert_nothing_raised do
      job.enque!
      WatchJob.drain
    end
    Time.unstub(:now)
  end

  test "should get number of likes and shares from Facebook link" do
    link = create_link url: 'https://facebook.com/749262715138323/posts/990190297712229'
    resp = link.check_facebook_numbers
    assert_equal 2, resp['likes']
    assert_equal 1, resp['shares']
    assert_equal resp, link.data
  end

  test "should return false if number of likes and shares from Facebook link did not change" do
    link = create_link url: 'https://facebook.com/749262715138323/posts/990190297712229'
    resp = link.check_facebook_numbers
    resp = link.check_facebook_numbers
    assert !resp
  end

  test "should return false if exception is thrown when getting numbers from Facebook" do
    Link.any_instance.expects(:get_shares_and_likes_from_facebook).raises(RuntimeError)
    link = create_link url: 'https://facebook.com/749262715138323/posts/990190297712229'
    resp = link.check_facebook_numbers
    assert !resp
    Link.any_instance.unstub(:get_shares_and_likes_from_facebook)
  end

  test "should get number of likes and retweets from Twitter link from API" do
    link = create_link url: 'https://twitter.com/statuses/638402604188303360'
    resp = link.check_twitter_numbers_from_api
    assert_equal 3, resp['shares']
    assert_equal 4, resp['likes']
    assert_equal resp, link.data
  end

  test "should return false if number of likes and shares from Twitter link from API did not change" do
    link = create_link url: 'https://twitter.com/statuses/638402604188303360'
    resp = link.check_twitter_numbers_from_api
    resp = link.check_twitter_numbers_from_api
    assert !resp
  end

  test "should return false if exception is thrown when getting numbers from Twitter API" do
    Link.any_instance.expects(:get_shares_and_likes_from_twitter_api).raises(RuntimeError)
    link = create_link url: 'https://twitter.com/statuses/638402604188303360'
    resp = link.check_twitter_numbers_from_api
    assert !resp
    Link.any_instance.unstub(:get_shares_and_likes_from_twitter_api)
  end

  test "should get number of likes and retweets from Twitter link from HTML" do
    link = create_link url: 'https://twitter.com/statuses/638402604188303360'
    resp = link.check_twitter_numbers_from_html
    assert_equal 3, resp['shares']
    assert_equal 4, resp['likes']
    assert_equal resp, link.data
  end

  test "should return false if number of likes and shares from Twitter link from HTML did not change" do
    link = create_link url: 'https://twitter.com/statuses/638402604188303360'
    resp = link.check_twitter_numbers_from_html
    resp = link.check_twitter_numbers_from_html
    assert !resp
  end

  test "should return false if exception is thrown when getting numbers from Twitter HTML" do
    Link.any_instance.expects(:get_shares_and_likes_from_twitter_html).raises(RuntimeError)
    link = create_link url: 'https://twitter.com/statuses/638402604188303360'
    resp = link.check_twitter_numbers_from_html
    assert !resp
    Link.any_instance.unstub(:get_shares_and_likes_from_twitter_html)
  end

  test "should not create link from invalid application" do
    assert_no_difference 'Link.count' do
      assert_raises Mongoid::Errors::Validations do
        create_link application: 'invalid'
      end
    end 
  end

  test "should not create link without application" do
    assert_no_difference 'Link.count' do
      assert_raises Mongoid::Errors::Validations do
        create_link application: nil
      end
    end 
  end

  test "should not create same link under same application" do
    assert_difference 'Link.count' do
      create_link url: 'http://test.com'
    end
    assert_no_difference 'Link.count' do
      assert_raises Mongoid::Errors::Validations do
        create_link url: 'http://test.com'
      end
    end
  end

  test "should check that Facebook post is offline" do
    l = create_link url: 'https://facebook.com/749262715138323/posts/996333003764625'
    l.check404
    assert_equal 404, l.status
  end

  test "should check that Facebook post is online" do
    l = create_link url: 'https://facebook.com/749262715138323/posts/994636317267627'
    l.check404
    assert_equal 200, l.status
  end

  test "should check that tweet is offline" do
    l = create_link url: 'https://twitter.com/statuses/642613929693175809'
    l.check404
    assert_equal 404, l.status
  end

  test "should check that tweet is online" do
    l = create_link url: 'https://twitter.com/statuses/642147950081130496'
    l.check404
    assert_equal 200, l.status
  end

  test "should run jobs in background" do
    l = nil
    l = create_link url: 'https://twitter.com/statuses/613227868726804481'
    j = l.job
    j.enque!
    WatchJob.drain
    assert_equal 2, l.reload.data['shares']
    assert_equal 1, l.reload.data['likes']
  end

  test "should restart background job if memory is exhausted and environment is production" do
    Watchbot::Memory.stubs(:value).returns(1000000001)
    Rails.stubs(:env).returns('production')
    Kernel.expects(:system).returns(true).once
    
    l = create_link url: 'https://twitter.com/statuses/613227868726804481'
    l.job.enque!
    WatchJob.drain

    Watchbot::Memory.unstub(:value)
    Rails.unstub(:env)
    Kernel.unstub(:system)
  end

  test "should not restart background job if memory is not exhausted" do
    Watchbot::Memory.stubs(:value).returns(999999999)
    Rails.stubs(:env).returns('production')
    Kernel.expects(:system).never
    
    l = create_link url: 'https://twitter.com/statuses/613227868726804481'
    l.job.enque!
    WatchJob.drain

    Watchbot::Memory.unstub(:value)
    Rails.unstub(:env)
    Kernel.unstub(:system)
  end

  test "should not restart background job if environment is not production" do
    Watchbot::Memory.stubs(:value).returns(1000000001)
    Kernel.expects(:system).never
    
    l = create_link url: 'https://twitter.com/statuses/613227868726804481'
    l.job.enque!
    WatchJob.drain

    Watchbot::Memory.unstub(:value)
    Rails.unstub(:env)
    Kernel.unstub(:system)
  end

  test "should restart checker when periodicity changes" do
    Time.stubs(:now).returns(Time.parse('2015-01-02 09:00:00'))
    t = Time.parse('2015-01-01 09:00:00')
    link = create_link created_at: t
    job = link.job

    t = Time.parse('2015-01-02 09:06:00')
    assert_equal Time.parse('2015-01-02 09:05:00'), link.reload.job.last_time(t)

    Time.stubs(:now).returns(Time.parse('2015-01-05 09:00:00'))
    t = Time.parse('2015-01-05 09:30:00')
    job.enque!
    WatchJob.drain
    assert_equal Time.parse('2015-01-05 09:00:00'), link.reload.job.last_time(t)

    Time.unstub(:now)
  end

  def teardown
    Link.any_instance.unstub(:get_config)
  end
end
