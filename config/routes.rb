Rails.application.routes.draw do
  devise_for :users,
    controllers: { sessions: "users/sessions" },
    skip: [ :registrations ]

  resources :users, only: [ :index, :new, :create ]

  # Web UI
  root "matches#index"

  resources :matches, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    resources :frames, only: [ :show ], shallow: true do
      resources :visits, only: [ :create ] do
        resources :shots, only: [ :create ]
      end
      member do
        get  :stats
        post :end_visit
        post :complete
        post :confirm_result
        post :undo
        post :remove_red
        post :restore_red
        post :start_clock
        post :pause_clock
      end
    end
    member do
      get  :stats
      get  :watch
      post :start
      post :finish
    end
  end

  # API
  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"
      delete "auth/logout", to: "auth#logout"
      post "auth/register", to: "auth#register"

      resources :matches, only: [ :index, :show, :create ] do
        resources :frames, only: [ :show, :index ], shallow: true do
          resources :visits, only: [ :create, :index ] do
            resources :shots, only: [ :create ]
          end
          member do
            post :end_visit
            post :complete
          end
        end
        member do
          post :start
        end
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
