require 'watch_job'
WATCHBOT_CONFIG = {}
Dir.glob("#{Rails.root.to_s}/config/applications/#{Rails.env}/*.yml").each do |config_file|
  name = File.basename(config_file, '.yml')
  WATCHBOT_CONFIG[name] = YAML.load_file(config_file)
end
WebMock.allow_net_connect!
