# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [
  :password, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  :authorization, :authentication, :jwt, :api_key, :private_key, :public_key
]