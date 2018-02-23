require 'yaml'
require 'active_support/core_ext/hash'
require_relative 'config_validator_errors.rb'

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
    @config_compiler ||= ConfigCompiler.new(
      market_partner_product: @market_partner_product,
      config_path: @config_path,
      root_path: @root_path)
  end

  def is_array_valid?(object:, valid_config:, object_name:, object_data_type:, object_trace:, parent_object:)
    # handle value_types, allowed, allowed_min/_max
    true
  end

  def is_string_valid?(object:, valid_config:, object_name:, object_data_type:, object_trace:, parent_object:)
    # handle validations: Array of { type, parameters }
    true
  end

end
