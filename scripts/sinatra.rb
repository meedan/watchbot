require 'sinatra'
require 'json'

post '/payload' do
  request.body.rewind
  payload = request.body.read
  verify_signature(payload)
  push = JSON.parse(payload)
  puts "JSON received: #{push.inspect}"
end

def verify_signature(payload)
  signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['SECRET_TOKEN'], payload)
  return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_WATCHBOT_SIGNATURE'])
end
