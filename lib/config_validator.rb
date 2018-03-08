require 'active_support/core_ext/hash'
require 'colorize'
require 'json'
require 'yaml'

class ConfigValidator
  SUPPORTED_CONFIG_VERSIONS = %w(3.0)
  def self.printable_object_trace(message, object_trace, object = '')
    trace_string = object_trace.join(' > ')
    divided_on_file = trace_string.split('.yml > ')
    divided_on_file[0] = divided_on_file[0].gsub(' > ', '/').colorize(:light_white)
    trace_with_file_division = divided_on_file.join ".yml\n\t".colorize(:light_white)
    pretty_object = object.try(:empty?) ? '' : ("\n" + object.to_yaml)
    message + trace_with_file_division + pretty_object
  end

  def self.reset_counters!
    @@errors = []
    @@objects = Hash.new { |h, k| h[k] = {} }
    @@terminal_objects = []
  end

  def self.root_path
    File.dirname(__FILE__)
  end

  def initialize(market_partner_product: '',
                 config_path: 'config/customer_application',
                 root_path: nil,
                 config_version: '3.0')
    return "Config version #{config_version} not supported." unless SUPPORTED_CONFIG_VERSIONS.include?(config_version)
    @market_partner_product = market_partner_product.to_sym
    @config_path = config_path
    @root_path = root_path || ::Rails.root rescue self.class.root_path
    @config_version = config_version
  end

  def generate_schema(version: '3.0', output: :yaml)
    @data_types = ObjectValidatorBase.reload_data_types!(version)
    @schema = {}
    @key_path = []
    add_schema_nodes!
  end

  def add_schema_nodes(node: :root_config)
    config = @data_types[:root_config]
    config[:required].each do |key, config|
      # TODO
    end
  end

  def reload!
    @config_compiler = nil
    config_compiler.configs_to_test
    ObjectValidatorBase.reload_data_types!
    true
  end

  def validate
    self.class.reset_counters!
    config = config_compiler.configs_to_test.each do |mpp, config|
      renderer_version = @config_version.to_i.to_s
      load_renderer_version_specific_files renderer_version
      args = {
        object: config,
        object_data_type: :root_config,
        object_name: :'config.yml',
        object_trace: [mpp],
        renderer_version: renderer_version
      }
      puts "Validating #{mpp}".colorize(:light_magenta)
      HashValidator.new(args).valid?
    end

    reset_object_counter!
    object_counter(config)
    print_results
  end

  private

  def config_compiler(market_partner_product: nil, config_path: nil, root_path: nil, config_version: nil)
    @config_compiler ||= Compiler.new(
      market_partner_product: market_partner_product || @market_partner_product,
      config_path: config_path || @config_path,
      root_path: root_path || @root_path,
      config_version: config_version || @config_version)
  end

  def load_renderer_version_specific_files(version)
    dir = File.dirname(__FILE__)
    %w(object_validator_base.rb string_validator.rb array_validator.rb hash_validator.rb).each do |file|
      outcome = "Ok!".colorize(:green)
      full_file_path = "#{dir}/config_validator/v#{version}/#{file}"
      print "#{('Loading v' + version.to_s + ':').colorize(:light_yellow)} #{full_file_path}..."
      load full_file_path
      puts outcome
    end
  rescue Exception => e
    outcome = "FAILED :(".colorize(:red)
    puts outcome
    raise e
  end

  def print_errors
    puts('All good!'.colorize(:green)) if @@errors.empty?

    err_totals = Hash.new { |h, k| h[k] = 0 }
    err_msgs = @@errors.map do |err|
      err_class = err.class.to_s.colorize(:red)
      err_totals[err_class.colorize(:red)] += 1
      "#{err_class.colorize(:red).bold}: #{err.message}"
    end

    puts "\n#{err_msgs.join("\n")}\n"
    puts "#{err_msgs.length} errors:".colorize(:yellow).bold
    err_totals.each { |err_class, count| puts("#{err_class}: #{count}") }
  end

  def print_results
    print_errors

    objects, counter = [@objects.keys.length, @@objects.keys.length] # this is just to avoid the ruby syntax bug in sublime :( https://github.com/sublimehq/Packages/issues/1150
    print "\n#{counter}".colorize(:light_white).bold
    print " objects validated out of "
    puts objects.to_s.colorize(:light_white).bold

    coverage = (counter * 100.0 / objects).round(2)
    color = coverage >= 90 ? :green : coverage >= 50 ? :yellow : :red
    puts "Validation coverage: #{(coverage.to_s + '%').colorize color}"
    @@errors.empty?
  end

  # TODO: refactor out into ObjectCounter class
  def reset_object_counter!
    @objects = {}
  end

  def object_counter(obj)
    if obj.respond_to? :keys
      hash_key_counter(obj)
    elsif obj.respond_to? :join
      array_element_counter(obj)
    else
      @objects[obj.object_id] = true
    end
  end

  def hash_key_counter(hsh)
    return unless hsh.respond_to? :keys
    @objects[hsh.object_id] = true
    hsh.keys.each do |key|
      next if key.to_s.include?('attrs')
      object_counter hsh[key]
    end
  end

  def array_element_counter(arr)
    return unless arr.respond_to? :join
    @objects[arr.object_id] = true
    arr.each do |el|
      object_counter el
    end
  end

end

require_relative 'config_validator/core_refinements.rb'
require_relative 'config_validator/config_errors.rb'
require_relative 'config_validator/validator_errors.rb'
require_relative 'config_validator/compiler.rb'
