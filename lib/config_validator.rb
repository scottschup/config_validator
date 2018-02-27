require 'active_support/core_ext/hash'
require 'colorize'
require 'json'
require 'yaml'

class ConfigValidator
  def self.printable_object_trace(message, object_trace)
    trace_string = object_trace.join(' > ')
    divided_on_file = trace_string.split('.yml > ')
    divided_on_file[0].gsub!(' > ', '/')
    trace_with_file_division = divided_on_file.join('.yml ::: ')
    message + trace_with_file_division
  end

  def initialize(market_partner_product: '',
                 config_path: 'sample_config/customer_application',
                 root_path: nil)
    @market_partner_product = market_partner_product.to_sym
    @config_path = config_path
    @root_path = root_path || defined?(Rails) ? Rails.root : Dir.pwd
  end

  def start_validation
    ObjectValidatorBase.reset_errors!
    config_compiler.configs_to_test.each do |mpp, config|
      args = {
        object: config,
        object_data_type: :config,
        object_name: :'config.yml',
        object_trace: [mpp]
      }
      HashValidator.new(args).is_valid?
    end

    errors = ObjectValidatorBase.class_eval('@@errors')
    if errors.empty?
      puts 'All good!'.colorize(:green)
      return
    end
    err_msgs = errors.map { |err| "#{err.class.to_s.colorize(:red).bold}: #{err.message}" }

    puts
    puts "#{err_msgs.length} errors:".colorize(:yellow).bold
    puts "\n#{err_msgs.join("\n")}"
  end

  def reload!
    @config_compiler = nil
    config_compiler.configs_to_test
    ObjectValidatorBase.reload_data_types!
    true
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
require_relative 'config_validator/string_validator.rb'
require_relative 'config_validator/array_validator.rb'
require_relative 'config_validator/hash_validator.rb'
