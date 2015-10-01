Watchbot::Application.routes.draw do
  resources :links, only: [:create]
  delete "/links/:url" => "links#destroy", constraints: { url: /.*/ }

  require 'sidekiq/web'
  require 'sidekiq/cron/web'
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    username == SIDEKIQ_CONFIG[:web_user] && password == SIDEKIQ_CONFIG[:web_password]
  end
  mount Sidekiq::Web, at: '/sidekiq'
end
