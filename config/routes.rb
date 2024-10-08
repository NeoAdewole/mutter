Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  get 'about', to: 'about#index'

  match '/auth/:provider/callback', to: 'sessions#create', via: %i[get post]
  get '/auth/failure', to: 'omniauth_callbacks#failure'

  resource :session
  resource :registration
  resources :twitter_accounts, only: %i[index create destroy]
  resources :tweets, only: %i[index new create]
  resources :identities, only: [:destroy]

  resource :password_reset
  resource :password

  # Defines the root path route ("/")
  root 'main#index'
end
