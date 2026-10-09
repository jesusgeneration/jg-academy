Rails.application.routes.draw do
  devise_for :users, path: "auth", controllers: { registrations: "users/registrations" }

  root "dashboards#show"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  resource :dashboard, only: :show

  resources :organizations
  resources :users do
    patch :confirm, on: :member
  end
  resources :programs do
    resources :program_attendances, only: %i[create update destroy]
  end

  resources :units do
    resources :unit_attendances, only: %i[create update destroy]
    resources :unit_coverages, only: %i[create destroy]
    member do
      get :inherit_attendances
      post :inherit_attendances, action: :apply_attendances
    end
  end
end
