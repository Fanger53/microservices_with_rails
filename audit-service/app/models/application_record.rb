class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Enable PaperTrail for all models by default
  has_paper_trail

  # Rails 8 - Generate UUIDs for new records
  before_create :set_uuid
  
  private
  
  def set_uuid
    self.id = SecureRandom.uuid if id.blank? && self.class.column_names.include?('id')
  end
end