Rails.application.routes.draw do
  devise_for :users, path: "auth"

  root "dashboards#show"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  resource :dashboard, only: :show

  resources :juleica_requirements
  resources :organizations
  resources :users

  resources :courses do
    resources :course_attendances, only: %i[create update destroy]
  end
end
