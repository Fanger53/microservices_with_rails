class AuditLogRelationship < ApplicationRecord
  # Associations
  belongs_to :parent_log, class_name: 'AuditLog'
  belongs_to :child_log, class_name: 'AuditLog'

  # Rails 8 - Enhanced enums
  enum :relationship_type, {
    caused_by: 0,     # El evento hijo fue causado por el padre
    triggered: 1,     # El evento padre disparó el hijo
    related_to: 2,    # Eventos relacionados pero sin causalidad directa
    follows: 3,       # El evento hijo sigue temporalmente al padre
    compensates: 4    # El evento hijo compensa/revierte el padre
  }, prefix: true, validate: true

  # Validations
  validates :parent_log, :child_log, :relationship_type, presence: true
  validates :parent_log_id, uniqueness: { 
    scope: :child_log_id,
    message: 'relationship already exists between these logs'
  }
  
  # Prevent self-referencing relationships
  validate :prevent_self_reference
  validate :prevent_circular_references

  # Scopes
  scope :by_type, ->(type) { where(relationship_type: type) }
  scope :causal, -> { where(relationship_type: [:caused_by, :triggered]) }
  scope :temporal, -> { where(relationship_type: [:follows]) }

  private

  def prevent_self_reference
    if parent_log_id == child_log_id
      errors.add(:child_log, "cannot be the same as parent log")
    end
  end

  def prevent_circular_references
    return unless parent_log_id && child_log_id

    # Check if creating this relationship would create a circular reference
    if would_create_cycle?
      errors.add(:base, "would create a circular reference")
    end
  end

  def would_create_cycle?
    # Simple cycle detection - check if child already has parent as a descendant
    visited = Set.new
    current = child_log_id

    while current && !visited.include?(current)
      visited.add(current)
      
      # Find next parent in the chain
      relationship = AuditLogRelationship.find_by(child_log_id: current)
      break unless relationship
      
      current = relationship.parent_log_id
      
      # If we've reached our intended parent, we have a cycle
      return true if current == parent_log_id
    end

    false
  end
end