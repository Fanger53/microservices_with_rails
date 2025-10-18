class Customer < ApplicationRecord
  # Rails 8 - Enums mejorados
  enum :status, { 
    inactive: 0, 
    active: 1, 
    suspended: 2, 
    deleted: 3 
  }, validate: true

  enum :tax_regime, { 
    simplified: 0, 
    common: 1, 
    special: 2 
  }, validate: true

  # Rails 8 - Encryption para datos sensibles (comentado para simplificar)
  # encrypts :tax_id, deterministic: true    # Permite búsquedas
  # encrypts :email, deterministic: true
  # encrypts :phone, deterministic: false    # Máxima seguridad

  # Validaciones mejoradas Rails 8
  validates :tax_id, presence: true, uniqueness: true
  validates :tax_id, format: { 
    with: /\A\d{8,11}\z/, 
    message: "debe tener entre 8 y 11 dígitos" 
  }
  validates :name, presence: true, length: { minimum: 2, maximum: 200 }
  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :company_size, inclusion: { 
    in: %w[micro small medium large], 
    allow_blank: true 
  }

  # Rails 8 - Custom validation with pattern matching
  validate :validate_tax_regime_rules

  # Callbacks optimizados
  before_validation :normalize_data
  after_create_commit :trigger_customer_created_event
  after_update_commit :trigger_customer_updated_event, if: :saved_changes?

  # Scopes optimizados Rails 8
  scope :active, -> { where(status: :active) }
  scope :by_tax_regime, ->(regime) { where(tax_regime: regime) }
  scope :invoiceable, -> { active.where.not(email: nil) }
  scope :by_company_size, ->(size) { where(company_size: size) }
  scope :recent, -> { order(created_at: :desc) }

  # Métodos de dominio
  def can_invoice?
    active? && tax_id.present? && email.present? && valid_tax_info?
  end

  def display_name
    "#{name} (#{tax_id})"
  end

  def full_address
    [address, city, country].compact.join(', ')
  end

  # Rails 8 - Method para datos fiscales
  def tax_info
    {
      tax_id: tax_id,
      tax_regime: tax_regime,
      company_size: company_size,
      name: name,
      address: full_address,
      email: email,
      status: status
    }
  end

  private

  # Rails 8 - Pattern matching para validaciones complejas
  def validate_tax_regime_rules
    return unless tax_regime.present? && company_size.present?

    case [tax_regime, company_size]
    in ['simplified', size] if %w[micro small].include?(size)
      # Válido para régimen simplificado
    in ['common', size] if %w[medium large].include?(size)
      # Válido para régimen común  
    in ['special', _]
      # Régimen especial siempre válido
    else
      errors.add(:tax_regime, "no corresponde al tamaño de empresa")
    end
  end

  def normalize_data
    self.tax_id = tax_id.to_s.gsub(/\D/, '') if tax_id.present?
    self.email = email.to_s.downcase.strip if email.present?
    self.name = name.to_s.strip.titleize if name.present?
  end

  def valid_tax_info?
    tax_id.present? && name.present? && email.present?
  end

  def trigger_customer_created_event
    # CustomerCreatedJob.perform_later(id) # Por ahora comentado
    Rails.logger.info "Customer created: #{id}"
  end

  def trigger_customer_updated_event
    # CustomerUpdatedJob.perform_later(id, previous_changes) # Por ahora comentado
    Rails.logger.info "Customer updated: #{id}"
  end
end