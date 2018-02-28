require 'active_support/core_ext/hash'
require 'colorize'
require 'json'
require 'yaml'

class ConfigValidator
  def self.printable_object_trace(message, object_trace)
    trace_string = object_trace.join(' > ')
    divided_on_file = trace_string.split('.yml > ')
    divided_on_file[0] = divided_on_file[0].gsub(' > ', '/').colorize(:light_white)
    trace_with_file_division = divided_on_file.join ".yml\n\t".colorize(:light_white)
    message + trace_with_file_division
  end

  def initialize(market_partner_product: '',
                 config_path: 'sample_config/customer_application',
                 root_path: nil)
    @market_partner_product = market_partner_product.to_sym
    @config_path = config_path
    @root_path = root_path || defined?(Rails) ? Rails.root : Dir.pwd
  end

  def validate
    ObjectValidatorBase.reset_class_vars!
    config_compiler.configs_to_test.each do |mpp, config|
      args = {
        object: config,
        object_data_type: :config,
        object_name: :'config.yml',
        object_trace: [mpp]
      }
      HashValidator.new(args).valid?
    end

    puts "\n#{ObjectValidatorBase.class_eval('@@counter')} objects validated.".colorize(:light_white).bold
    errors = ObjectValidatorBase.class_eval('@@errors')
    return true if errors.empty?
    print_errors
    false
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

  def print_errors
    errors = ObjectValidatorBase.class_eval('@@errors')
    return puts('All good!'.colorize(:green)) if errors.empty?

    err_totals = Hash.new { |h, k| h[k] = 0 }
    err_msgs = errors.map do |err|
      err_class = err.class.to_s.colorize(:red)
      err_totals[err_class.colorize(:red)] += 1
      "#{err_class.colorize(:red).bold}: #{err.message}"
    end

    puts "#{err_msgs.length} errors:".colorize(:yellow).bold
    puts "\n#{err_msgs.join("\n")}\n"
    err_totals.each { |err_class, count| puts("#{err_class}: #{count}") }
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
