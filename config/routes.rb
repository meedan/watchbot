Watchbot::Application.routes.draw do
  resources :links, only: [:create, :destroy]
end
