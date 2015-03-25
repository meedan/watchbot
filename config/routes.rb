Watchbot::Application.routes.draw do
  resources :links, only: [:create]
  delete "/links/:url" => "links#destroy", constraints: { url: /.*/ }
end
