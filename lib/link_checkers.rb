module LinkCheckers

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
end
