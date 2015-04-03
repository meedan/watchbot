require 'watch_job'
WATCHBOT_CONFIG = YAML.load_file("#{Rails.root.to_s}/config/watchbot.yml")[Rails.env]
WebMock.allow_net_connect!
