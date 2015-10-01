sidekiq = YAML.load_file(File.join(Rails.root, 'config', 'sidekiq.yml'))
Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{sidekiq[:redis_host]}:#{sidekiq[:redis_port]}/#{sidekiq[:redis_database]}", namespace: "sidekiq_watchbot_#{Rails.env}" }
end
