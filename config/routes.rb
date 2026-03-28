Rails.application.routes.draw do
  devise_for :users,
    controllers: {
      sessions: "users/sessions",
      registrations: "users/registrations"
    }

  # Web UI
  root "matches#index"

  resources :matches, only: [ :index, :show, :new, :create ] do
    resources :frames, only: [ :show ], shallow: true do
      resources :visits, only: [ :create ] do
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
