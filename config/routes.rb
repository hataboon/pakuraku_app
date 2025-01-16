Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }
  root "static_pages#top"

  resources :foods, only: [ :index, :new, :create, :edit, :update, :destroy ]
  resources :recipes, only: [ :index, :new, :create, :show, :edit, :update ]
  resources :calendar_plans, only: [ :destroy ]
  resource :nutritions, only: [:show]
end
