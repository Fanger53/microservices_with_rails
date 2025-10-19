class InvoiceItem < ApplicationRecord
  # Asociaciones
  belongs_to :invoice

  # Rails 8 - Enums mejorados
  enum :tax_category, {
    standard: 'standard',
    reduced: 'reduced', 
    exempt: 'exempt',
    zero: 'zero'
  }, validate: true

  enum :unit_of_measure, {
    unit: 'UND',
    kilogram: 'KGM',
    liter: 'LTR',
    meter: 'MTR',
    hour: 'HUR',
    service: 'SRV'
  }, validate: true

  # Validaciones Rails 8
  validates :description, presence: true, length: { minimum: 3, maximum: 500 }
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :line_number, presence: true, numericality: { greater_than: 0 }
  validates :line_number, uniqueness: { scope: :invoice_id }
  validates :discount_percentage, numericality: { 
    greater_than_or_equal_to: 0, 
    less_than: 100 
  }
  validates :tax_rate, numericality: { 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 1 
  }

  # Rails 8 - Custom validations
  validate :validate_line_calculations
  validate :validate_tax_exempt_rules

  # Callbacks
  before_validation :set_line_number, if: -> { line_number.blank? }
  before_save :calculate_line_totals
  after_save :update_invoice_totals
  after_destroy :update_invoice_totals

  # Scopes
  scope :by_product, ->(code) { where(product_code: code) }
  scope :taxable, -> { where(tax_exempt: false) }
  scope :tax_exempt, -> { where(tax_exempt: true) }
  scope :ordered, -> { order(:line_number) }

  # Métodos de cálculo
  def calculate_line_subtotal
    base_amount = quantity * unit_price
    self.discount_amount = base_amount * (discount_percentage / 100.0)
    self.line_subtotal = base_amount - discount_amount
  end

  def calculate_tax_amount
    return 0 if tax_exempt?
    
    tax_base = line_subtotal
    self.tax_amount = tax_base * tax_rate
  end

  def calculate_line_total
    self.line_total = line_subtotal + tax_amount
  end

  def calculate_all_amounts!
    calculate_line_subtotal
    calculate_tax_amount
    calculate_line_total
    save!
  end

  # Rails 8 - Method para integración DIAN
  def dian_payload
    {
      line_number: line_number,
      product_code: product_code,
      description: description,
      quantity: quantity,
      unit_price: unit_price,
      line_total: line_total,
      tax_amount: tax_amount,
      tax_rate: tax_rate
    }
  end

  # Métodos de utilidad
  def effective_unit_price
    return unit_price if discount_percentage.zero?
    unit_price * (1 - discount_percentage / 100.0)
  end

  def has_discount?
    discount_percentage > 0 || discount_amount > 0
  end

  def tax_percentage
    (tax_rate * 100).round(2)
  end

  private

  # Rails 8 - Pattern matching para validaciones complejas
  def validate_line_calculations
    return unless quantity.present? && unit_price.present?
    
    expected_subtotal = (quantity * unit_price) - discount_amount
    expected_tax = tax_exempt? ? 0 : expected_subtotal * tax_rate
    expected_total = expected_subtotal + expected_tax
    
    case [line_subtotal, expected_subtotal]
    in [actual, expected] if (actual - expected).abs > 0.01
      errors.add(:line_subtotal, "cálculo incorrecto")
    else
      # Válido
    end
    
    case [tax_amount, expected_tax]
    in [actual, expected] if (actual - expected).abs > 0.01
      errors.add(:tax_amount, "cálculo de impuesto incorrecto")
    else
      # Válido
    end
  end

  def validate_tax_exempt_rules
    if tax_exempt? && tax_amount > 0
      errors.add(:tax_amount, "debe ser 0 para productos exentos")
    end
    
    if tax_category == 'exempt' && !tax_exempt?
      errors.add(:tax_exempt, "debe ser true para categoría exenta")
    end
  end

  def set_line_number
    return unless invoice.present?
    
    max_line = invoice.invoice_items.maximum(:line_number) || 0
    self.line_number = max_line + 1
  end

  def calculate_line_totals
    calculate_line_subtotal
    calculate_tax_amount
    calculate_line_total
  end

  def update_invoice_totals
    return unless invoice.present?
    
    # Solo recalcular si la factura no está cancelada
    invoice.calculate_totals! unless invoice.cancelled?
  end
end