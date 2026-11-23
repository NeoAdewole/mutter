Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  get 'about', to: 'about#index'
  # The live chat used to be /streaming; /streaming is now the Streaming section's landing page.
  get 'streaming/live-chat', to: 'streaming#show', as: :live_chat

  match '/auth/:provider/callback', to: 'sessions#create', via: %i[get post]
  get '/auth/failure', to: 'omniauth_callbacks#failure'

  resource :session
  resource :registration
  resources :twitter_accounts, only: %i[index create destroy]
  resources :tweets, only: %i[index new create]
  resources :identities, only: [:destroy]

  resource :password_reset
  resource :password

  namespace :admin do
    root to: 'dashboard#show'
    resources :pages, except: :show do
      member do
        patch :publish
        patch :unpublish
        patch :move
      end
      resources :blocks, only: :create
    end
    # A page's blocks, and the slides / cards inside them (see PageBlock and BlockItem).
    resources :blocks, only: %i[edit update destroy] do
      member { patch :move }
      resources :items, controller: 'block_items', only: %i[new create]
    end
    resources :items, controller: 'block_items', only: %i[edit update destroy] do
      member { patch :move }
    end
    resources :users, only: %i[index show edit update destroy] do
      member do
        patch :grant_admin
        patch :revoke_admin
        patch :suspend
        patch :unsuspend
        post :send_password_reset
      end
      resources :identities, only: :destroy
    end
    resources :audit_logs, only: :index
    resource :settings, only: %i[show update]
    resource :system, only: :show, controller: 'system' do
      post :clear_cache
    end
  end

  # CMS content. Keep these after every fixed route above: they claim
  # /streaming, /content, /gaming, /community and everything beneath them.
  section_key = Regexp.union(%w[streaming content gaming community])
  get ':section', to: 'sections#show', as: :section, constraints: { section: section_key }
  get ':section/*path', to: 'pages#show', as: :cms_page, format: false, constraints: { section: section_key }

  # Defines the root path route ("/")
  root 'main#index'
end
