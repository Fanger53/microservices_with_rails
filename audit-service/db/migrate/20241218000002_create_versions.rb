class CreateVersions < ActiveRecord::Migration[8.0]
  # Esta migración es para PaperTrail - versionado automático
  def change
    create_table :versions, id: :uuid do |t|
      t.string   :item_type, null: false
      t.string   :item_id,   null: false
      t.string   :event,     null: false
      t.string   :whodunnit
      t.json     :object,    limit: 1.gigabyte
      t.json     :object_changes, limit: 1.gigabyte

      # Metadatos adicionales para auditoría
      t.string   :source_service
      t.string   :correlation_id
      t.inet     :ip_address
      t.string   :user_agent
      t.json     :metadata

      t.timestamps null: false

      t.index [:item_type, :item_id], name: 'idx_versions_item'
      t.index :whodunnit, name: 'idx_versions_whodunnit'
      t.index :created_at, name: 'idx_versions_created_at'
      t.index :source_service, name: 'idx_versions_source_service'
      t.index :correlation_id, name: 'idx_versions_correlation'
    end
  end
end