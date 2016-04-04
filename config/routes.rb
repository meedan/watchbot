Watchbot::Application.routes.draw do
  resources :links, only: [:create]
  delete "/links/bulk" => "links#bulk_destroy"
  delete "/links/:url" => "links#destroy", constraints: { url: /.*/ }
  post "/links/bulk" => "links#bulk_create"

  require 'sidekiq/web'
  Sidekiq::Web.set 'views', File.join(Rails.root, 'app', 'views', 'sidekiq')
  if !SIDEKIQ_CONFIG[:web_user].nil? && !SIDEKIQ_CONFIG[:web_password].nil?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      username == SIDEKIQ_CONFIG[:web_user] && password == SIDEKIQ_CONFIG[:web_password]
    end
  end
  mount Sidekiq::Web, at: '/sidekiq'
end
