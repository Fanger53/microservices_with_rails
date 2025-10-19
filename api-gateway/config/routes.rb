Rails.application.routes.draw do
  # Health check endpoints
  get '/health', to: 'health#check'
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication endpoints
  namespace :auth do
    post 'login', to: 'sessions#create'
    post 'logout', to: 'sessions#destroy'
    post 'refresh', to: 'sessions#refresh'
    get 'me', to: 'sessions#show'
  end

  # Gateway info
  get '/gateway/info', to: 'gateway#info'
  get '/gateway/services', to: 'gateway#services'
  get '/gateway/metrics', to: 'gateway#metrics'

  # Proxied routes to microservices
  namespace :api do
    namespace :v1 do
      # Customer Service proxy routes
      scope '/customers', controller: 'proxy' do
        match '*path', via: :all, action: 'customer_service', as: 'customer_proxy'
      end
      
      # Invoice Service proxy routes  
      scope '/invoices', controller: 'proxy' do
        match '*path', via: :all, action: 'invoice_service', as: 'invoice_proxy'
      end
      
      # Audit Service proxy routes
      scope '/audit', controller: 'proxy' do
        match '*path', via: :all, action: 'audit_service', as: 'audit_proxy'
      end

      # Aggregated endpoints (combina datos de múltiples servicios)
      namespace :aggregated do
        get 'dashboard', to: 'dashboard#index'
        get 'customer/:id/full_profile', to: 'customers#full_profile'
        get 'invoice/:id/complete_details', to: 'invoices#complete_details'
        get 'reports/business_summary', to: 'reports#business_summary'
      end
    end
  end

  # Webhook endpoints para eventos de servicios
  namespace :webhooks do
    post 'customer_events', to: 'events#customer'
    post 'invoice_events', to: 'events#invoice'
    post 'audit_events', to: 'events#audit'
    post 'system_events', to: 'events#system'
  end

  # Fallback route para capturar rutas no definidas
  match '*path', to: 'application#route_not_found', via: :all

  # Root route
  root to: proc { [200, {}, ['API Gateway v1.0 - Electronic Invoicing System']] }
end