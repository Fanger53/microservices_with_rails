class CreateInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices, id: :uuid do |t|
      # Referencia al cliente (del Customer Service)
      t.uuid :customer_id, null: false
      
      # Datos básicos de la factura
      t.string :invoice_number, null: false, limit: 50
      t.string :invoice_type, null: false, default: 'standard', limit: 20
      t.date :issue_date, null: false
      t.date :due_date
      
      # Montos y cálculos
      t.decimal :subtotal, precision: 15, scale: 2, null: false, default: 0
      t.decimal :tax_amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :discount_amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :total_amount, precision: 15, scale: 2, null: false, default: 0
      
      # Información tributaria
      t.decimal :tax_rate, precision: 5, scale: 4, null: false, default: 0.19
      t.string :currency, null: false, default: 'COP', limit: 3
      
      # Estados y control
      t.integer :status, null: false, default: 0
      t.integer :payment_status, null: false, default: 0
      
      # Metadatos DIAN (futura integración)
      t.string :dian_uuid, limit: 100
      t.string :dian_response_code, limit: 10
      t.text :dian_response_message
      t.datetime :dian_sent_at
      t.datetime :dian_approved_at
      
      # Archivos generados
      t.string :pdf_file_path
      t.string :xml_file_path
      
      # Observaciones y notas
      t.text :notes
      t.text :internal_notes
      
      # Auditoría
      t.string :created_by, limit: 100
      t.string :updated_by, limit: 100
      t.datetime :cancelled_at
      t.string :cancelled_by, limit: 100
      t.text :cancellation_reason
      
      t.timestamps null: false
    end

    # Índices para performance y búsquedas
    add_index :invoices, :customer_id
    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, :status
    add_index :invoices, :payment_status
    add_index :invoices, :issue_date
    add_index :invoices, :dian_uuid, unique: true, where: "dian_uuid IS NOT NULL"
    add_index :invoices, [:status, :issue_date]
    add_index :invoices, [:customer_id, :status]
    add_index :invoices, :created_at
    
    # Índice compuesto para reportes
    add_index :invoices, [:issue_date, :status, :total_amount], name: 'idx_invoices_reports'
  end
end