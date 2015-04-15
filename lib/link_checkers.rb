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
    w = self.get_google_worksheet
    before = Digest::MD5.hexdigest(w.rows.join)
    sleep 30
    w.reload
    after = Digest::MD5.hexdigest(w.rows.join)
    # If something changed during that time it's because someone is still editing - so, we don't want to notify
    before === after
  end

  def get_google_worksheet
    require 'google_drive'
    session = GoogleDrive::Session.login(WATCHBOT_CONFIG['settings']['google_email'], WATCHBOT_CONFIG['settings']['google_password'])
    key = self.url.gsub(/https:\/\/docs\.google\.com\/a\/meedan\.net\/spreadsheets\/d\/([^\/]+)\/.*/, '\1')
    ss = session.spreadsheet_by_key(key)
    ss.worksheet_by_title(URI.parse(self.url).fragment)
  end

end
