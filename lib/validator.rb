require 'active_support/core_ext/hash'
require 'yaml'
require 'json'

# Monkey patch Hash to use deep_symbolize_keys
class Hash
  def deep_symbolize_keys
    JSON.parse(JSON[self], symbolize_names: true)
  end
end

class ConfigValidator
  DATA_TYPES = YAML.load_file('./lib/data_types.yml')
  MPPS = %i(us_avantcredit_installment us_avantcredit_credit_card us_eloan_installment)
  PAGES_WITHOUT_DIRS = %i(home declined service_failure)
  SUPPORTED_CLASSES = [Array, Hash, String, Fixnum]

  # Config Errors
  class ConfigError < StandardError
    def initialize(message, error_hash={})
      if trace = error_hash[:trace]
        puts message
        super trace.join(' > ')
      else
        super message
      end
    end
  end
  class RootConfigNotFoundError < ConfigError; end
  class VersionConfigNotFoundError < ConfigError; end
  class PageConfigNotFoundError < ConfigError; end
  class InvalidClassError < ConfigError; end
  class UnsupportedClassError < ConfigError; end
  class MissingRequiredParameterError < ConfigError; end
  class TooFewParametersError < ConfigError; end
  class TooManyParametersError < ConfigError; end
  class InvalidParameterError < ConfigError; end

  # Validator Errors
  class ConfigValidatorError < ConfigError
    def initialize(message, error_hash)
      location = error_hash[:location]
      error_hash.delete :location if location
      super(message, error_hash)
      puts location
    end
  end
  class MissingDataTypeError < ConfigValidatorError; end

  def initialize(mpp: nil,
      config_path: 'config/customer_application',
      root_path: nil)
    @config_path = config_path
    @root_path = root_path || defined?(Rails) ? Rails.root : Dir.pwd
    @market_partner_product = mpp ? mpp.to_sym : mpp
    @current_params = {}
    @shared_configs = []
  end

  def compiled_configs
    if @market_partner_product
      return build_config(@market_partner_product)
    end
    build_all_configs
  end

  def configs_to_test
    @configs_to_test ||= compiled_configs
  end

  def is_valid?(object:, object_data_type:, object_name:, object_trace:, parent_object: {})
    object_trace = update_object_trace(object_trace, object_name)
    print_object_trace(object_trace, object_name, "Validating:")

    actual_class = object.class
    case object_data_type
    when String
      expected_class = object_data_type.constantize
      return is_class_supported?(actual_class) && is_class_valid?(actual_class, [expected_class], object_trace)
    when Symbol
      valid_config = DATA_TYPES[object_data_type]
      unless valid_config
        raise MissingDataTypeError.new "#{object_data_type} is missing from data_types.yml", { location: 'ConfigValidator#is_valid?', trace: object_trace }
      end

      expected_classes = valid_config[:object_classes] || [valid_config[:object_class]]
      return true if is_class_valid?(actual_class, expected_classes, object_trace) && object_data_type == :boolean
      send("is_#{object.class.to_s.downcase}_valid?",
        object: object,
        valid_config: valid_config,
        object_name: object_name,
        object_data_type: object_data_type,
        object_trace: object_trace,
        parent_object: parent_object)
    else
      raise InvalidClassError.new "Expected: String or Symbol; Actual: #{actual_class}", { trace: object_trace }
    end
  end

  def start_validation
    all_good = configs_to_test.all? do |mpp, config|
      # config at this point is a Hash with keys :active_version and :apply
      is_valid? object: config,
        object_data_type: :config,
        object_name: :'config.yml',
        object_trace: [mpp]
    end
    puts(all_good ? 'All good.' : 'Something happened :(')
  end

  # private

  def add_params_required_from_sister_to_current_params!(object, object_name, object_data_type, valid_config, parent_object)
    return unless new_reqs = valid_config[:required_from_sister]
    new_reqs.each do |new_req|
      sister_vals = parent_object[new_req[:sister_key]]
      sister_vals.each do |sister_val|
        req_key = new_req[:req_key] % { sister_val: sister_val }
        req_val = new_req[:req_val].to_s % { sister_val: sister_val }
        @current_params[object_data_type] ||= {}
        @current_params[object_data_type][req_key.to_sym] = req_val.to_sym
      end
    end
  end

  def build_config(mpp)
    config = load_root_config_yaml_file(mpp)
    config[:apply] = load_version_config_yaml_file(mpp).dig(:apply) || {}
    config.dig(:apply, :page_templates) && config[:apply][:page_templates].each do |page|
      page_configs = config[:apply][:page_configs] || {}
      next if page_configs.keys.include?(page.to_sym)
      page_configs[page] = load_page_config_yaml_file(mpp, page)
    end
    { mpp.to_sym => config }
  end

  def build_all_configs
    result = {}
    MPPS.each { |mpp| result.merge! build_config(mpp) }
    result
  end

  def calculate_required_and_allowed_key_numbers(object, valid_config)
    min = valid_config[:allowed_min]
    max = valid_config[:allowed_max]
    num_required_keys = (valid_config[:required] || {}).keys.length + (min || 0)
    num_extra_keys = object.keys.length - num_required_keys
    num_allowed_keys = num_required_keys + (max || num_extra_keys)
    [num_required_keys, num_allowed_keys]
  end

  def remove_shared_configs_from_current_params!(object, object_name, object_data_type)
    @temp_hidden_params = {}
    if object_name == :shared_configs
      @shared_configs = object.dup
    elsif object_name == :component_configs
      @shared_configs.each do |shared_component_name, config|
        deleted = @current_params[object_data_type].delete shared_component_name
        @temp_hidden_params[shared_component_name] = config unless deleted.nil?
      end
    end
  end

  def return_shared_configs_to_current_params!(object, object_name, object_data_type)
    return unless object_name == :component_configs
    @current_params[object_data_type].merge!(@temp_hidden_params.dup)
  end

  def has_only_allowed_keys?(object, object_name, object_data_type, valid_config)
    @current_params[object_data_type].merge!(valid_config[:allowed] || {})
    return_shared_configs_to_current_params!(object, object_name, object_data_type)

    allowed_when = valid_config[:allowed_when]
    allowed_when && allowed_when.each do |key_to_check, conditional_values|
      value = object[key_to_check]
      conditional_values.each do |value_to_check, conditionally_allowed|
        @current_params[object_data_type].merge!(conditionally_allowed) if value_to_check == value
      end
    end

    @extra_keys = object.keys.map(&:to_sym) - @current_params[object_data_type].keys
    @extra_keys.length.zero?
  end

  def has_all_required_keys?(object, object_name, object_data_type, valid_config, parent_object)
    @current_params[object_data_type] = (valid_config[:required] || {}).dup
    add_params_required_from_sister_to_current_params!(object, object_name, object_data_type, valid_config, parent_object)
    remove_shared_configs_from_current_params!(object, object_name, object_data_type)

    required_when = valid_config[:required_when]
    required_when && required_when.each do |key_to_check, conditional_values|
      value = object[key_to_check]
      conditional_values.each do |value_to_check, conditionally_required|
        @current_params[object_data_type].merge!(conditionally_required) if value_to_check == value
      end
    end

    @missing_keys = @current_params[object_data_type].keys - object.keys.map(&:to_sym)
    @missing_keys.length.zero?
  end

  def is_class_supported?(actual_class, object_trace)
    SUPPORTED_CLASSES.include?(actual_class)
  end

  def is_class_valid?(actual_class, expected_classes, object_trace)
    expected_classes.map! { |klass| klass.class == Class ? klass : klass.constantize }
    unless expected_classes.include? actual_class
      raise InvalidClassError.new "Expected: #{expected_classes.join(' or ')}; Got: #{actual_class}", { trace: object_trace }
    end
    true
  end

  def is_hash_valid?(object:, valid_config:, object_name:, object_data_type:, object_trace:, parent_object:)
    # Note: the order of these checks is important as keys are added to 
    #   @current_params[object_data_type] for use at various points through the process
    unless has_all_required_keys?(object, object_name, object_data_type, valid_config, parent_object)
      raise MissingRequiredParameterError.new "#{object_name} is missing required parameter(s): #{@missing_keys.join(', ')}", { trace: object_trace }
    end

    # Should be using @current_params[object_data_type]
    # num_required_keys, num_allowed_keys = calculate_required_and_allowed_key_numbers(object, valid_config)
    # actual_num_keys = object.keys.length

    # if actual_num_keys > num_allowed_keys
    #   raise TooManyParametersError.new "#{object_name} only allows #{num_allowed_keys} parameters, but found #{actual_num_keys}", { trace: object_trace }
    # end

    # if actual_num_keys < num_required_keys
    #   raise TooFewParametersError.new "#{object_name} requires #{num_required_keys} parameters, but found #{actual_num_keys}", { trace: object_trace }
    # end

    unless has_only_allowed_keys?(object, object_name, object_data_type, valid_config)
      raise InvalidParameterError.new "#{object_name} does not allow these parameter(s): #{@extra_keys.join(', ')}", { trace: object_trace }
    end

    object.each do |next_object_name, next_object|
      next_data_type = @current_params[object_data_type][next_object_name.to_sym]
      binding.pry if ![Symbol, String].include?(next_data_type.class)

      case next_data_type
      when Symbol
        is_valid?(
          object: next_object,
          object_data_type: next_data_type,
          object_name: next_object_name,
          object_trace: object_trace,
          parent_object: object
        )
      when String
        actual_class = next_object.class.to_s
        unless actual_class == next_data_type
          update_object_trace(object_trace, next_object_name)
          raise InvalidClassError.new "Expected: #{next_data_type}; Actual: #{actual_class}", { trace: object_trace }
        end
      else
        raise ConfigValidatorError.new "Invalid next_data_type. Expected: Symbol or String; Actual class: #{actual_class}, value: #{next_data_type}", { trace: object_trace }
      end
    end
  end

  def is_array_valid?(object:, valid_config:, object_name:, object_data_type:, object_trace:, parent_object:)
    # handle value_types, allowed, allowed_min/_max
    true
  end

  def is_string_valid?(object:, valid_config:, object_name:, object_data_type:, object_trace:, parent_object:)
    # handle validations: Array of { type, parameters }
    true
  end

  def load_root_config_yaml_file(mpp)
    file_path = File.join(@root_path,
      @config_path,
      mpp.to_s,
      'config.yml')
    puts "Loading: #{file_path}"
    YAML.load_file(file_path).deep_symbolize_keys 
  rescue StandardError => e
    raise RootConfigNotFoundError.new "Missing root config.yml for #{mpp}"
  end

  def load_version_config_yaml_file(mpp)
    # TODO account for different active versions
    file_path = File.join(@root_path,
      @config_path,
      mpp.to_s,
      'v',
      '1',
      'version_config.yml')
    puts "Loading: #{file_path}"
    YAML.load_file(file_path).deep_symbolize_keys
  rescue StandardError => e
    raise VersionConfigNotFoundError.new "Missing v1 version_config.yml for #{mpp}"
  end

  def load_page_config_yaml_file(mpp, page)
    file_path = File.join(@root_path,
      @config_path,
      mpp.to_s,
      'v',
      '1',
      'stage_variants',
      page,
      'page_config.yml')
    puts "Loading: #{file_path}"
    YAML.load_file(file_path).deep_symbolize_keys
  rescue StandardError => e
    if e.message.include? 'No such file'
      raise PageConfigNotFoundError.new "Missing #{page} page_config.yml for #{mpp}"
    else
      raise StandardError, e
    end
  end

  def print_object_trace(object_trace, object_name, message)
    ellipses = object_trace.length > 7 ? '...' : ''
    trace_string = object_trace.last(7).join(' > ')
    divided_on_file = trace_string.split('.yml > ')
    divided_on_file[0].gsub!(' > ', '/')
    trace_with_file_division = divided_on_file.join('.yml ::: ')
    puts "#{message} #{ellipses}#{trace_with_file_division}"
  end

  def update_object_trace(object_trace, object_name)
    # root config is handled with start_evaluate naming
    if object_name == :apply
      object_trace = [object_trace.first]
      object_to_add = [:v, :'1', :'version_config.yml', object_name]
    elsif PAGES_WITHOUT_DIRS.include?(object_name.to_sym)
      object_trace = object_trace.first(3)
      object_to_add = [:'version_config.yml', :page_configs, object_name]
    elsif object_trace.last == :page_configs && !PAGES_WITHOUT_DIRS.include?(object_name.to_sym)
      object_trace = object_trace.first(3)
      object_to_add = [:stage_variants, object_name, :'page_config.yml', object_name]
    else
      object_to_add = [object_name]
    end
    object_trace + object_to_add
  end
end
