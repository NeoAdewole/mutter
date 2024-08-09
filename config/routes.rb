Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "about", to: "about#index"

  get '/auth/failure', to: 'omniauth_callbacks#failure'
  get '/auth/twitter/callback', to: 'sessions#create'
  get '/auth/github/callback', to: 'sessions#create'

  resources :twitter_accounts, only: [:index, :create, :destroy]
  resources :tweets, only: [:index, :new, :create]

  resource :session
  resource :registration
  resource :password_reset
  resource :password

  # Defines the root path route ("/")
  root "main#index"
end
