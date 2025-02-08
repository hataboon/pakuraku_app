Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions",
    omniauth_callbacks: "users/omniauth_callbacks",
    passwords: "users/passwords"
  }
  root "static_pages#top"

  resources :foods, only: [ :index, :new, :create, :edit, :update, :destroy ]
  resources :recipes, only: [ :index, :new, :create, :show, :edit, :update ]
  resources :calendar_plans, only: [ :destroy ]
  resource :nutrition, only: [ :show ]
  resources :calendar_plans, only: [ :destroy, :edit, :update ]

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
