Rails.application.routes.draw do
  # Health check endpoint
  get '/health', to: 'health#check'
  
  # Reveal health status on /up that returns 200 if the app boots with no exceptions
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Audit logs management
      resources :audit_logs, only: [:index, :show, :create] do
        collection do
          get :search
          get :summary
          get :metrics
          get :by_service
          get :by_action
          get :by_date_range
        end
      end

      # Events endpoint for receiving audit events from other services
      resources :events, only: [:create] do
        collection do
          post :batch # For batch event processing
        end
      end

      # Reporting endpoints
      namespace :reports do
        get :daily_summary
        get :service_activity
        get :error_trends
        get :compliance_report
        get :user_activity
      end

      # System monitoring
      namespace :monitoring do
        get :service_status
        get :metrics
        get :performance
      end
    end
  end

  # Webhook endpoints for external integrations
  namespace :webhooks do
    post :customer_events
    post :invoice_events
    post :system_events
  end

  # Root path for service discovery
  root to: proc { [200, {}, ['Audit Service API v1.0 - Electronic Invoicing System']] }
end