Rails.application.routes.draw do
  # Health check endpoint
  get "health", to: "health#show"
  
  namespace :api do
    namespace :v1 do
      resources :customers do
        member do
          get :validate_invoice_capability
        end
        
        collection do
          get :search
        end
      end
    end
  end
end
