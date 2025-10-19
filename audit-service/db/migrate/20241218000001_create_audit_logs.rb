class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs, id: :uuid do |t|
      # Identificación del evento
      t.string :event_id, null: false, index: { unique: true }
      t.string :correlation_id, index: true

      # Información del servicio origen
      t.string :service_name, null: false, index: true
      t.string :service_version, default: '1.0.0'
      t.string :environment, null: false, default: 'development'

      # Acción realizada
      t.string :action, null: false, index: true
      t.string :resource_type, null: false, index: true
      t.string :resource_id, index: true

      # Usuario y contexto
      t.string :user_id, index: true
      t.string :user_type # customer, admin, system, external
      t.string :user_email
      t.inet :ip_address

      # Request/Response información
      t.string :http_method
      t.string :endpoint
      t.text :request_params
      t.text :response_body
      t.integer :response_status

      # Metadatos del evento
      t.json :metadata # Flexible para datos específicos del evento
      t.json :changes # Para tracking de cambios específicos
      t.text :description

      # Estados y categorización
      t.integer :severity, default: 0 # info, warn, error, critical
      t.integer :category, default: 0 # business, security, system, performance
      t.integer :status, default: 0   # pending, processed, failed

      # Auditoría y compliance
      t.boolean :sensitive_data, default: false
      t.boolean :pii_data, default: false # Personally Identifiable Information
      t.string :compliance_tags, array: true, default: []

      # Performance metrics
      t.float :duration_ms
      t.integer :memory_usage_mb

      # Error handling
      t.text :error_message
      t.text :error_backtrace
      t.string :error_class

      # Timestamps
      t.timestamp :occurred_at, null: false, index: true
      t.timestamps

      # Indexes para queries eficientes
      t.index [:service_name, :action], name: 'idx_audit_logs_service_action'
      t.index [:resource_type, :resource_id], name: 'idx_audit_logs_resource'
      t.index [:user_id, :occurred_at], name: 'idx_audit_logs_user_time'
      t.index [:severity, :occurred_at], name: 'idx_audit_logs_severity_time'
      t.index [:category, :service_name], name: 'idx_audit_logs_category_service'
      t.index :correlation_id, name: 'idx_audit_logs_correlation'
      t.index "occurred_at DESC", name: 'idx_audit_logs_occurred_desc'
    end

    # Tabla para eventos relacionados (correlación de eventos)
    create_table :audit_log_relationships, id: :uuid do |t|
      t.references :parent_log, type: :uuid, null: false, foreign_key: { to_table: :audit_logs }
      t.references :child_log, type: :uuid, null: false, foreign_key: { to_table: :audit_logs }
      t.string :relationship_type # caused_by, triggered, related_to, follows
      t.text :relationship_context

      t.timestamps

      t.index [:parent_log_id, :child_log_id], unique: true, name: 'idx_audit_relationships_unique'
    end

    # Tabla para agregaciones y métricas pre-calculadas
    create_table :audit_summaries, id: :uuid do |t|
      t.string :summary_type, null: false # daily, hourly, service, user
      t.string :dimension_key, null: false # service_name, user_id, action, etc.
      t.string :dimension_value, null: false
      t.date :summary_date
      t.integer :summary_hour

      # Contadores
      t.integer :total_events, default: 0
      t.integer :success_events, default: 0
      t.integer :error_events, default: 0
      t.integer :warning_events, default: 0

      # Métricas de performance
      t.float :avg_duration_ms, default: 0.0
      t.float :max_duration_ms, default: 0.0
      t.float :min_duration_ms, default: 0.0

      # Metadatos del resumen
      t.json :metadata

      t.timestamps

      t.index [:summary_type, :dimension_key, :dimension_value, :summary_date], 
              unique: true, name: 'idx_audit_summaries_unique'
      t.index [:summary_date, :summary_type], name: 'idx_audit_summaries_date_type'
    end
  end
end