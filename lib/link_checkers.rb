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

end
