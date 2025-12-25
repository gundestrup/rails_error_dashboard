RailsErrorDashboard::Engine.routes.draw do
  root to: "errors#index"

  resources :errors, only: [ :index, :show ] do
    member do
      post :resolve
    end
    collection do
      get :analytics
      get :platform_comparison
      get :correlation
      post :batch_action
    end
  end
end
