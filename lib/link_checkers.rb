module LinkCheckers
  def check_facebook_numbers
    get_shares_and_likes(:get_shares_and_likes_from_facebook)
  end

  def check_twitter_numbers_from_api
    get_shares_and_likes(:get_shares_and_likes_from_twitter_api)
  end

  def check_twitter_numbers_from_html
    get_shares_and_likes(:get_shares_and_likes_from_twitter_html)
  end

  def check404
    uri = URI.parse(self.url).normalize
    code = 0
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      result = http.get(uri.path)
      code = result.code.to_i
    rescue SocketError
      code = 404
    end
    self.update_attributes(status: code) if code != self.status
    code / 100 === 4
  end

  def check_google_spreadsheet_updated
    require 'digest/md5'
    w = Retryable.retryable tries: 5 do
      self.get_google_worksheet
    end
    before = Digest::MD5.hexdigest(w.rows.join)
    return false if before === self.data['hash']
    sleep 30
    w.reload
    after = Digest::MD5.hexdigest(w.rows.join)
    # If something changed during that time it's because someone is still editing - so, we don't want to notify
    if before === after
      self.data['hash'] = after
      self.save!
      return true
    else
      return false
    end
  end

  def get_google_worksheet
    require 'google_drive'

    session = spreadsheet = nil
    key = self.url.gsub(/https:\/\/docs\.google\.com\/.*\/d\/([^\/]+)\/.*/, '\1')

    begin
      access_token = Rails.cache.fetch('!google_access_token') do
        generate_google_access_token
      end
      session = GoogleDrive.login_with_oauth(access_token)
      spreadsheet = session.spreadsheet_by_key(key)
    rescue Google::APIClient::AuthorizationError
      access_token = generate_google_access_token
      Rails.cache.write('!google_access_token', access_token)
      session = GoogleDrive.login_with_oauth(access_token)
      spreadsheet = session.spreadsheet_by_key(key)
    end

    spreadsheet.worksheet_by_title(URI.parse(self.url).fragment)
  end
  
  protected

  def get_shares_and_likes(method)
    likes = self.data['likes'] || 0
    shares = self.data['shares'] || 0
    begin
      numbers = send(method)
      likes = numbers['likes']
      shares = numbers['shares']
    rescue
      return false
    end

    if likes == self.data['likes'] && shares = self.data['shares']
      return false
    end
    self.data = { 'likes' => likes, 'shares' => shares }
    self.save!
    self.data
  end

  private

  def generate_google_access_token
    require 'google/api_client'
    require 'google/api_client/client_secrets'
    require 'google/api_client/auth/installed_app'
    
    client = Google::APIClient.new(
      :application_name => 'Watchbot',
      :application_version => '1.0.0'
    )
    
    key = Google::APIClient::KeyUtils.load_from_pkcs12(WATCHBOT_CONFIG['settings']['google_pkcs12_path'], WATCHBOT_CONFIG['settings']['google_pkcs12_secret'])
    client.authorization = Signet::OAuth2::Client.new(
      :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
      :audience => 'https://accounts.google.com/o/oauth2/token',
      :scope => ['https://www.googleapis.com/auth/drive', 'https://spreadsheets.google.com/feeds/'],
      :issuer => WATCHBOT_CONFIG['settings']['google_issuer'],
      :signing_key => key)
    client.authorization.fetch_access_token!
    client.authorization.access_token
  end

  def connect_to_twitter
    Twitter::REST::Client.new do |config|
      config.consumer_key        = WATCHBOT_CONFIG['settings']['twitter_consumer_key']
      config.consumer_secret     = WATCHBOT_CONFIG['settings']['twitter_consumer_secret']
      config.access_token        = WATCHBOT_CONFIG['settings']['twitter_access_token']
      config.access_token_secret = WATCHBOT_CONFIG['settings']['twitter_access_token_secret']
    end
  end

  def get_shares_and_likes_from_facebook
    graph = Koala::Facebook::API.new(WATCHBOT_CONFIG['settings']['facebook_auth_token'])
    object = graph.get_object(self.url.gsub(/^https?:\/\/(www\.)?facebook\.com\//, ''), fields: 'likes.summary(true),shares.summary(true)')
    { 'likes' => object['likes']['summary']['total_count'], 'shares' => object['shares']['count'] }
  end

  def get_shares_and_likes_from_twitter_api
    id = self.url.gsub(/^https?:\/\/(www\.)?twitter\.com\/statuses\//, '')
    tweet = connect_to_twitter.status(id)
    { 'likes' => tweet.favorite_count, 'shares' => tweet.retweet_count }
  end

  def get_shares_and_likes_from_twitter_html
    data = parse_html({ 'likes' => '.js-stat-favorites strong', 'shares' => '.js-stat-retweets strong' })
    { 'likes' => data['likes'].to_i, 'shares' => data['shares'].to_i }
  end

  # grok: key => CSS selector
  def parse_html(groks = {})
    require 'open-uri'
    require 'nokogiri'
    html = open(self.url)
    doc = Nokogiri::HTML(html)
    resp = {}
    groks.each do |key, css|
      resp[key] = doc.css(css).inner_html
    end
    resp
  end
end
