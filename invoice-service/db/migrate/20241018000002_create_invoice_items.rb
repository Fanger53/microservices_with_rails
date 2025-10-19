class CreateInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    create_table :invoice_items, id: :uuid do |t|
      # Referencia a la factura
      t.uuid :invoice_id, null: false
      
      # Datos del producto/servicio
      t.string :product_code, limit: 50
      t.string :description, null: false, limit: 500
      t.decimal :quantity, precision: 10, scale: 4, null: false, default: 1
      t.string :unit_of_measure, limit: 10, default: 'UND'
      
      # Precios y cálculos
      t.decimal :unit_price, precision: 15, scale: 4, null: false
      t.decimal :discount_percentage, precision: 5, scale: 2, default: 0
      t.decimal :discount_amount, precision: 15, scale: 2, default: 0
      t.decimal :line_subtotal, precision: 15, scale: 2, null: false
      
      # Información tributaria por línea
      t.decimal :tax_rate, precision: 5, scale: 4, null: false, default: 0.19
      t.decimal :tax_amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :line_total, precision: 15, scale: 2, null: false
      
      # Clasificaciones tributarias
      t.string :tax_category, limit: 50, default: 'standard'
      t.boolean :tax_exempt, default: false
      
      # Metadatos adicionales
      t.text :notes
      t.integer :line_number, null: false
      
      t.timestamps null: false
    end

    # Índices para performance
    add_index :invoice_items, :invoice_id
    add_index :invoice_items, :product_code
    add_index :invoice_items, [:invoice_id, :line_number], unique: true
    add_index :invoice_items, :tax_category
    
    # Foreign key constraint
    add_foreign_key :invoice_items, :invoices, on_delete: :cascade
  end
end