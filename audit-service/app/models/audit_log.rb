class AuditLog < ApplicationRecord
  # Rails 8 - Enhanced enums with advanced features
  enum :severity, { 
    info: 0, 
    warn: 1, 
    error: 2, 
    critical: 3 
  }, prefix: true, validate: true

  enum :category, { 
    business: 0,     # Operaciones de negocio
    security: 1,     # Eventos de seguridad
    system: 2,       # Eventos del sistema
    performance: 3,  # Métricas de rendimiento
    compliance: 4    # Eventos de cumplimiento
  }, prefix: true, validate: true

  enum :status, { 
    pending: 0, 
    processed: 1, 
    failed: 2 
  }, prefix: true, validate: true

  # Associations
  has_many :parent_relationships, 
           class_name: 'AuditLogRelationship', 
           foreign_key: 'child_log_id',
           dependent: :destroy
           
  has_many :child_relationships, 
           class_name: 'AuditLogRelationship', 
           foreign_key: 'parent_log_id',
           dependent: :destroy
           
  has_many :parent_logs, through: :parent_relationships, source: :parent_log
  has_many :child_logs, through: :child_relationships, source: :child_log

  # Rails 8 - Enhanced validations with pattern matching
  validates :event_id, presence: true, uniqueness: true
  validates :service_name, :action, :resource_type, :occurred_at, presence: true
  validates :severity, :category, :status, presence: true
  
  validates :event_id, format: { 
    with: /\A[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/i,
    message: 'must be a valid UUID'
  }
  
  validates :ip_address, format: { 
    with: /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\z/,
    message: 'must be a valid IPv4 address'
  }, allow_blank: true

  validates :response_status, inclusion: { 
    in: 100..599,
    message: 'must be a valid HTTP status code'
  }, allow_blank: true

  validates :duration_ms, numericality: { 
    greater_than_or_equal_to: 0,
    message: 'must be non-negative'
  }, allow_blank: true

  # Rails 8 - Pattern matching validations
  validates :service_name, inclusion: { 
    in: %w[customer-service invoice-service audit-service external-service],
    message: 'must be a valid service name'
  }

  validates :user_type, inclusion: { 
    in: %w[customer admin system external anonymous],
    message: 'must be a valid user type'
  }, allow_blank: true

  # Callbacks
  before_validation :set_defaults
  before_save :sanitize_sensitive_data
  after_create :process_audit_event

  # Scopes
  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_service, ->(service) { where(service_name: service) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_resource, ->(type, id = nil) { 
    scope = where(resource_type: type)
    scope = scope.where(resource_id: id) if id.present?
    scope
  }
  scope :in_date_range, ->(start_date, end_date) { 
    where(occurred_at: start_date..end_date) 
  }
  scope :with_errors, -> { where.not(error_message: nil) }
  scope :successful, -> { where(error_message: nil) }
  scope :slow_operations, ->(threshold = 1000) { 
    where('duration_ms > ?', threshold) 
  }

  # Class methods for analytics
  class << self
    def daily_summary(date = Date.current)
      where(occurred_at: date.beginning_of_day..date.end_of_day)
        .group(:service_name, :severity)
        .count
    end

    def service_performance_metrics(service_name, start_date = 1.day.ago)
      where(service_name: service_name, occurred_at: start_date..)
        .where.not(duration_ms: nil)
        .group(:action)
        .average(:duration_ms)
    end

    def error_trends(days = 7)
      where(occurred_at: days.days.ago..)
        .where.not(error_message: nil)
        .group_by_day(:occurred_at)
        .group(:service_name)
        .count
    end

    def compliance_report(start_date, end_date)
      where(occurred_at: start_date..end_date)
        .where(category: :compliance)
        .group(:service_name, :action)
        .count
    end

    def search(query)
      return none if query.blank?
      
      where(
        "description ILIKE ? OR action ILIKE ? OR resource_type ILIKE ? OR user_email ILIKE ?",
        "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
      )
    end
  end

  # Instance methods
  def duration_in_seconds
    return nil unless duration_ms.present?
    duration_ms / 1000.0
  end

  def has_error?
    error_message.present?
  end

  def is_sensitive?
    sensitive_data? || pii_data?
  end

  def related_events
    AuditLog.where(correlation_id: correlation_id).where.not(id: id)
  end

  def add_relationship(other_log, relationship_type, context = nil)
    AuditLogRelationship.create!(
      parent_log: self,
      child_log: other_log,
      relationship_type: relationship_type,
      relationship_context: context
    )
  end

  # Rails 8 - JSON serialization with performance optimizations
  def as_json(options = {})
    super(options.merge(
      except: [:request_params, :response_body, :error_backtrace],
      methods: [:duration_in_seconds, :has_error?],
      include: {
        child_logs: { only: [:id, :event_id, :action, :occurred_at] }
      }
    ))
  end

  # Elasticsearch/OpenSearch integration
  def indexable_data
    {
      id: id,
      event_id: event_id,
      service_name: service_name,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      user_id: user_id,
      severity: severity,
      category: category,
      occurred_at: occurred_at,
      duration_ms: duration_ms,
      response_status: response_status,
      has_error: has_error?,
      description: description,
      metadata: metadata
    }
  end

  private

  def set_defaults
    self.event_id ||= SecureRandom.uuid
    self.occurred_at ||= Time.current
    self.environment ||= Rails.env
    self.service_version ||= '1.0.0'
    self.severity ||= :info
    self.category ||= :business
    self.status ||= :pending
  end

  def sanitize_sensitive_data
    if sensitive_data? || pii_data?
      # Remover información sensible de request_params y response_body
      self.request_params = sanitize_json_field(request_params)
      self.response_body = sanitize_json_field(response_body)
    end
  end

  def sanitize_json_field(field)
    return field unless field.present?
    
    begin
      parsed = JSON.parse(field) if field.is_a?(String)
      parsed ||= field
      
      # Remover campos sensibles comunes
      sensitive_fields = %w[password email phone ssn credit_card token secret]
      
      if parsed.is_a?(Hash)
        parsed.each do |key, value|
          if sensitive_fields.any? { |sf| key.to_s.downcase.include?(sf) }
            parsed[key] = '[REDACTED]'
          end
        end
      end
      
      parsed.to_json
    rescue JSON::ParserError
      '[SANITIZED]'
    end
  end

  def process_audit_event
    # Procesamiento asíncrono del evento de auditoría
    AuditEventProcessorJob.perform_later(id)
  end
end