require 'open-uri'
require 'nokogiri'

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
    code = 0
    begin
      response = get_http_response_for(self.url)
      code = response.code.to_i
      if code === 301 || code === 302
        code = get_http_response_for(response.header['location']).code.to_i
      end
    rescue SocketError
      code = 404
    end
    self.status = code
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

    # FIXME: Acceleration instead of absolute values?
    self.priority = likes + shares
    self.prioritized = self.prioritized?

    if likes == self.data['likes'] && shares = self.data['shares']
      return false
    end
    self.data = { 'likes' => likes, 'shares' => shares }
    self.data
  end

  def get_http_response_for(url)
    uri = URI.parse(url).normalize
    agent = { 'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2227.0 Safari/537.36' }
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.get(uri.path, agent)
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
    
    key = Google::APIClient::KeyUtils.load_from_pkcs12(get_config('settings')['google_pkcs12_path'], get_config('settings')['google_pkcs12_secret'])
    client.authorization = Signet::OAuth2::Client.new(
      :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
      :audience => 'https://accounts.google.com/o/oauth2/token',
      :scope => ['https://www.googleapis.com/auth/drive', 'https://spreadsheets.google.com/feeds/'],
      :issuer => get_config('settings')['google_issuer'],
      :signing_key => key)
    client.authorization.fetch_access_token!
    client.authorization.access_token
  end

  def connect_to_twitter
    Twitter::REST::Client.new do |config|
      config.consumer_key        = get_config('settings')['twitter_consumer_key']
      config.consumer_secret     = get_config('settings')['twitter_consumer_secret']
      config.access_token        = get_config('settings')['twitter_access_token']
      config.access_token_secret = get_config('settings')['twitter_access_token_secret']
    end
  end

  def get_shares_and_likes_from_facebook
    graph = Koala::Facebook::API.new(get_config('settings')['facebook_auth_token'])
    object = graph.get_object(self.url.gsub(/^https?:\/\/(www\.)?facebook\.com\/([0-9]+)\/posts\/([0-9]+).*/, '\2_\3'), fields: 'likes.summary(true),shares.summary(true)')
    likes = (object.has_key?('likes') && object['likes'].has_key?('summary')) ? object['likes']['summary']['total_count'].to_i : 0
    shares = (object.has_key?('shares')) ? object['shares']['count'].to_i : 0
    { 'likes' => likes, 'shares' => shares }
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
    html = ''
    open(self.url) do |f|
      html = f.read
    end
    doc = Nokogiri::HTML(html)
    resp = {}
    groks.each do |key, css|
      resp[key] = doc.css(css).inner_html
    end
    doc = nil
    resp
  end
end
