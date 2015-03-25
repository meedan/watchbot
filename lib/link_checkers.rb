module LinkCheckers

  def check404
    uri = URI.parse(self.url).normalize
    code = 0
    begin
      result = Net::HTTP.start(uri.host, uri.port) { |http| http.get(uri.path) }
      code = result.code.to_i
    rescue SocketError
      code = 404
    end
    self.update_attributes(status: code) if code != self.status
    code === 404
  end

end
