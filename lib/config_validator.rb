require 'active_support/core_ext/hash'
require 'colorize'
require 'json'
require 'yaml'

class ConfigValidator
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
    @@counter = 0
    @@terminal_objects = []
  end

  def initialize(market_partner_product: '',
                 config_path: 'sample_config/customer_application',
                 root_path: nil,
                 config_version: 1)
    @market_partner_product = market_partner_product.to_sym
    @config_path = config_path
    @root_path = root_path || defined?(Rails) ? Rails.root : Dir.pwd
    @config_version = config_version
  end

  def generate_schema
    
  end

  def reload!
    @config_compiler = nil
    config_compiler.configs_to_test
    ObjectValidatorBase.reload_data_types!
    true
  end

  def validate
    self.class.reset_counters!
    config = config_compiler(config_version: 1).configs_to_test.each do |mpp, config|
      @renderer_version = config.dig(:apply, :renderer_version)
      load_renderer_version_specific_files
      args = {
        object: config,
        object_data_type: :root_config,
        object_name: :'config.yml',
        object_trace: [mpp],
        renderer_version: @renderer_version
      }
      puts "\nValidating #{mpp}".colorize(:light_magenta)
      HashValidator.new(args).valid?
    end

    reset_object_counter!
    object_counter(config)
    print_results
  end

  private

  def config_compiler(config_version: 1)
    @config_compiler ||= Compiler.new(
      market_partner_product: @market_partner_product,
      config_path: @config_path,
      root_path: @root_path,
      config_version: config_version)
  end

  def load_renderer_version_specific_files
    dir = File.dirname(__FILE__)
    outcome = "DONE!".colorize(:green)
    print "Loading ".colorize(:light_yellow)
    print 'files from '
    print "#{dir}/config_validator/v#{@renderer_version}/ ...".colorize(:light_white)
    load "#{dir}/config_validator/v#{@renderer_version}/object_validator_base.rb"
    load "#{dir}/config_validator/v#{@renderer_version}/string_validator.rb"
    load "#{dir}/config_validator/v#{@renderer_version}/array_validator.rb"
    load "#{dir}/config_validator/v#{@renderer_version}/hash_validator.rb"
    puts outcome
  rescue Exception => e
    outcome = "FAILED :(".colorize(:red)
    puts outcome
    puts e.message
  ensure
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

    objects, counter = [@@objects.keys.length, @@counter] # this is just to avoid the ruby syntax bug in sublime :( https://github.com/sublimehq/Packages/issues/1150
    print "\n#{counter}".colorize(:light_white).bold
    print " objects validated out of "
    puts objects.to_s.colorize(:light_white).bold

    reset_object_counter!
    object_counter(@@terminal_objects.map { |obj_hash| obj_hash[:object] })
    skipped_objects = @@objects.keys.length
    puts "#{skipped_objects.to_s.colorize(:light_white).bold} objects skipped due to terminal parent objects"

    coverage = ((counter + skipped_objects) * 100.0 / objects).round(2)
    color = coverage >= 90 ? :green : coverage >= 50 ? :yellow : :red
    puts "Validation coverage: #{(coverage.to_s + '%').colorize color}"
    @@errors.empty?
  end

  def reset_object_counter!
    @@objects = {}
  end

  def object_counter(obj)
    if obj.respond_to? :keys
      key_counter(obj)
    elsif obj.respond_to? :join
      array_element_counter(obj)
    else
      @@objects[obj.object_id] = true
    end
  end

  def key_counter(hsh)
    return unless hsh.respond_to? :keys
    hsh.keys.each do |key|
      @@objects[hsh.keys.object_id] = true
      next if key.to_s.include?('attrs')
      object_counter hsh[key]
    end
  end

  def array_element_counter(arr)
    return unless arr.respond_to? :join
    arr.each do |el|
      @@objects[arr.object_id] = true
      object_counter el
    end
  end

end

require_relative 'config_validator/core_refinements.rb'
require_relative 'config_validator/config_errors.rb'
require_relative 'config_validator/validator_errors.rb'
require_relative 'config_validator/compiler.rb'
