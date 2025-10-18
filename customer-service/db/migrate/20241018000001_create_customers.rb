class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers, id: :uuid do |t|
      # Datos básicos
      t.string :tax_id, null: false, limit: 20
      t.string :name, null: false, limit: 200
      t.string :email, null: false, limit: 100
      t.string :phone, limit: 20
      
      # Dirección
      t.text :address
      t.string :city, limit: 100
      t.string :country, default: 'Colombia', limit: 50
      
      # Información fiscal
      t.integer :tax_regime, null: false, default: 0
      t.string :company_size, limit: 20
      
      # Estado y control
      t.integer :status, null: false, default: 1
      
      # Auditoría
      t.string :created_by, limit: 100
      t.string :updated_by, limit: 100
      
      t.timestamps null: false
    end

    # Índices para performance
    add_index :customers, :tax_id, unique: true
    add_index :customers, :email, unique: true
    add_index :customers, :status
    add_index :customers, :tax_regime
    add_index :customers, [:status, :tax_regime]
    add_index :customers, :created_at
  end
end