require 'yaml'
require 'json'
require 'active_support/core_ext/hash'

class ConfigValidator
  def initialize(market_partner_product: '',
                 config_path: 'sample_config/customer_application',
                 root_path: nil)
    @market_partner_product = market_partner_product.to_sym
    @config_path = config_path
    @root_path = root_path || defined?(Rails) ? Rails.root : Dir.pwd
  end

  def start_validation
    config_compiler.configs_to_test.all? do |mpp, config|
      args = {
        object: config,
        object_data_type: :config,
        object_name: :'config.yml',
        object_trace: [mpp]
      }
      HashValidator.new(args).is_valid?
    end
  end

  private

  def config_compiler
    @config_compiler ||= Compiler.new(
      market_partner_product: @market_partner_product,
      config_path: @config_path,
      root_path: @root_path)
  end

end

require_relative 'config_validator/core_refinements.rb'
require_relative 'config_validator/config_errors.rb'
require_relative 'config_validator/validator_errors.rb'
require_relative 'config_validator/compiler.rb'
require_relative 'config_validator/object_validator_base.rb'
require_relative 'config_validator/hash_validator.rb'
require_relative 'config_validator/array_validator.rb'
require_relative 'config_validator/string_validator.rb'
