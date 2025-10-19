class Invoice < ApplicationRecord
  # Rails 8 - Enums mejorados con validación automática
  enum :status, { 
    draft: 0, 
    issued: 1, 
    sent: 2, 
    approved: 3,
    cancelled: 4,
    rejected: 5
  }, validate: true

  enum :payment_status, { 
    pending: 0, 
    partial: 1, 
    paid: 2, 
    overdue: 3 
  }, validate: true

  enum :invoice_type, {
    standard: 'standard',
    credit_note: 'credit_note',
    debit_note: 'debit_note',
    export: 'export'
  }, validate: true

  # Asociaciones
  has_many :invoice_items, dependent: :destroy
  
  # Rails 8 - Encryption para datos sensibles
  # encrypts :dian_uuid, deterministic: false
  # encrypts :internal_notes, deterministic: false

  # Validaciones Rails 8 mejoradas
  validates :customer_id, presence: true
  validates :invoice_number, presence: true, uniqueness: true
  validates :invoice_number, format: { 
    with: /\A[A-Z]{1,3}-\d{6,}\z/, 
    message: "debe tener formato FV-123456" 
  }
  validates :issue_date, presence: true
  validates :subtotal, :tax_amount, :total_amount, 
            numericality: { greater_than_or_equal_to: 0 }
  validates :total_amount, numericality: { greater_than: 0 }
  validates :currency, inclusion: { in: %w[COP USD EUR] }
  validates :tax_rate, numericality: { 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 1 
  }

  # Rails 8 - Custom validation with pattern matching
  validate :validate_due_date_after_issue_date
  validate :validate_invoice_calculations
  validate :validate_cancellation_data

  # Callbacks optimizados
  before_validation :generate_invoice_number, if: -> { invoice_number.blank? }
  before_validation :set_due_date, if: -> { due_date.blank? }
  before_save :calculate_totals
  after_create_commit :trigger_invoice_created_event
  after_update_commit :trigger_invoice_updated_event, if: :saved_changes?

  # Scopes optimizados Rails 8
  scope :active, -> { where.not(status: :cancelled) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_date_range, ->(start_date, end_date) { where(issue_date: start_date..end_date) }
  scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }
  scope :pending_payment, -> { where(payment_status: [:pending, :partial, :overdue]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_items, -> { includes(:invoice_items) }

  # Métodos de dominio
  def can_be_cancelled?
    [:draft, :issued].include?(status.to_sym) && !cancelled?
  end

  def can_be_edited?
    draft? && !cancelled?
  end

  def is_overdue?
    due_date.present? && due_date < Date.current && !paid?
  end

  def days_overdue
    return 0 unless is_overdue?
    (Date.current - due_date).to_i
  end

  def calculate_totals!
    self.subtotal = invoice_items.sum(:line_subtotal)
    self.tax_amount = invoice_items.sum(:tax_amount)
    self.total_amount = subtotal + tax_amount - discount_amount
    save!
  end

  # Rails 8 - Method para integración DIAN
  def dian_payload
    {
      invoice_number: invoice_number,
      customer_id: customer_id,
      issue_date: issue_date,
      total_amount: total_amount,
      tax_amount: tax_amount,
      currency: currency,
      items: invoice_items.map(&:dian_payload)
    }
  end

  # Métodos para generación de documentos
  def generate_pdf!
    # Implementar con Prawn
    InvoicePdfGeneratorJob.perform_later(id)
  end

  def generate_xml!
    # Implementar para DIAN
    InvoiceXmlGeneratorJob.perform_later(id)
  end

  def send_to_dian!
    return false unless can_send_to_dian?
    DIANSubmissionJob.perform_later(id)
  end

  def cancel!(reason:, cancelled_by:)
    return false unless can_be_cancelled?
    
    update!(
      status: :cancelled,
      cancelled_at: Time.current,
      cancelled_by: cancelled_by,
      cancellation_reason: reason
    )
  end

  private

  # Rails 8 - Pattern matching para validaciones complejas
  def validate_due_date_after_issue_date
    return unless issue_date.present? && due_date.present?
    
    case [issue_date, due_date]
    in [issue, due] if issue > due
      errors.add(:due_date, "debe ser posterior a la fecha de emisión")
    else
      # Válido
    end
  end

  def validate_invoice_calculations
    return unless invoice_items.any?
    
    calculated_subtotal = invoice_items.sum(&:line_subtotal)
    calculated_tax = invoice_items.sum(&:tax_amount)
    
    errors.add(:subtotal, "no coincide con la suma de líneas") if subtotal != calculated_subtotal
    errors.add(:tax_amount, "no coincide con la suma de impuestos") if tax_amount != calculated_tax
  end

  def validate_cancellation_data
    if cancelled?
      errors.add(:cancelled_by, "es requerido") if cancelled_by.blank?
      errors.add(:cancellation_reason, "es requerida") if cancellation_reason.blank?
    end
  end

  def generate_invoice_number
    prefix = case invoice_type
             when 'standard' then 'FV'
             when 'credit_note' then 'NC'
             when 'debit_note' then 'ND'
             when 'export' then 'FE'
             else 'FV'
             end
    
    last_number = Invoice.where("invoice_number LIKE ?", "#{prefix}-%")
                        .maximum(:invoice_number)
                        &.split('-')&.last&.to_i || 0
    
    self.invoice_number = "#{prefix}-#{(last_number + 1).to_s.rjust(6, '0')}"
  end

  def set_due_date
    self.due_date = issue_date + 30.days if issue_date.present?
  end

  def calculate_totals
    return unless invoice_items.loaded? || invoice_items.any?
    
    self.subtotal = invoice_items.sum(&:line_subtotal)
    self.tax_amount = invoice_items.sum(&:tax_amount)
    self.total_amount = subtotal + tax_amount - discount_amount
  end

  def can_send_to_dian?
    issued? && dian_uuid.blank? && customer_id.present?
  end

  def trigger_invoice_created_event
    InvoiceCreatedJob.perform_later(id)
  end

  def trigger_invoice_updated_event
    InvoiceUpdatedJob.perform_later(id, previous_changes) if saved_changes.any?
  end
end