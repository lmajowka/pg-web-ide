Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "db_ide#index"

  get "db_ide", to: "db_ide#index"
  get "db_ide/sql_runner", to: "db_ide#sql_runner"
  post "db_ide/execute", to: "db_ide#execute"
  post "db_ide/sql_runner/execute", to: "db_ide#sql_runner_execute"
  post "db_ide/create", to: "db_ide#create"
  patch "db_ide/update", to: "db_ide#update"
  delete "db_ide/destroy", to: "db_ide#destroy"
  post "db_ide/switch_database", to: "db_ide#switch_database"
end
