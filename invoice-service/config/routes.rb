Rails.application.routes.draw do
  # Health check endpoint
  get "health", to: "health#show"
  
  namespace :api do
    namespace :v1 do
      resources :invoices do
        member do
          post :calculate_taxes
          post :generate_pdf
          post :send_to_dian
          patch :cancel
          get :status
        end
        
        collection do
          get :search
          get :summary
        end
        
        resources :items, controller: 'invoice_items', except: [:index]
      end
      
      # Reportes específicos de facturas
      get 'reports/daily', to: 'reports#daily'
      get 'reports/monthly', to: 'reports#monthly'
      get 'reports/tax_summary', to: 'reports#tax_summary'
    end
  end
end