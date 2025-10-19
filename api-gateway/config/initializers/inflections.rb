# Be sure to restart your server when you modify this file.

# Define an inflection method that maintains compatibility with Rails 8
ActiveSupport::Inflector.inflections(:en) do |inflect|
  # Define custom inflections here
  # Examples:
  # inflect.plural /^(ox)$/i, "\\1en"
  # inflect.singular /^(ox)en/i, "\\1"
  # inflect.irregular "person", "people"
  # inflect.uncountable %w( fish sheep )
  
  # API Gateway specific inflections
  inflect.acronym 'API'
  inflect.acronym 'JWT'
  inflect.acronym 'HTTP'
  inflect.acronym 'HTTPS'
  inflect.acronym 'URL'
  inflect.acronym 'JSON'
  inflect.acronym 'XML'
end