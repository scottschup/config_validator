require 'active_support/core_ext/hash'
require 'yaml'

class ConfigValidator
  DATA_TYPES = YAML.load_file('./data_types.yml')
  MPPS = %i(us_avantcredit_installment us_avantcredit_credit_card us_eloan_installment)
  PAGES_WITHOUT_DIRS = %w(home declined service_failure)
  SUPPORTED_CLASSES = [Array, Hash, String]

  class ConfigValidatorError < StandardError
    def initialize(msg1 = nil, msg2 = nil)
      super msg1
      puts(msg2.join ' > ') if msg2.try :respond_to?, :join
    end
  end
  class RootConfigNotFoundError < ConfigValidatorError; end
  class VersionConfigNotFoundError < ConfigValidatorError; end
  class PageConfigNotFoundError < ConfigValidatorError; end
  class UnsupportedClassError < ConfigValidatorError; end
  class MissingRequiredParameterError < ConfigValidatorError; end
  class InvalidNumberOfParametersError < ConfigValidatorError; end
  class InvalidClassError < ConfigValidatorError; end

  def initialize(market_partner_product: nil,
      config_path: 'config/customer_application',
      root_path: nil)
    @config_path = config_path
    @root_path = root_path || defined?(Rails) ? Rails.root : Dir.pwd
    @market_partner_product = market_partner_product.try(:to_sym)
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

    case object_data_type
    when String
      actual_class = object.class.to_s
      unless actual_class == object_data_type
        raise InvalidClassError, "Expected: #{object_data_type}; Actual: #{actual_class}", object_trace 
      end
      true
    when Symbol
      valid_config = DATA_TYPES[:object_data_type]
      if classes = valid_config[:object_classes]
        unless classes.include?(object.class)
          raise InvalidClassError, "Expected: #{classes.join(' or ')}; Actual: #{actual_class}", object_trace 
        end
        return true
      end
      is_class_valid?(object, valid_config) &&
        "is_#{object.class}_valid?".send(object, valid_config, object_trace, parent_object)
    else
      raise InvalidClassError, "Expected: String or Symbol; Actual: #{actual_class}", object_trace 
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
    puts('All good.') if all_good
  end

  # private

  def add_keys_required_from_sister_to_current_keys(object, parent)
    return unless new_reqs = object[:required_from_sister]
    new_reqs.each do |new_req|
      sister_vals = parent[new_req[:sister_key]]
      sister_vals.each do |sister_val|
        req_key = new_req[:req_key] % { sister_val: sister_val }
        req_val = new_req[:req_val] % { sister_val: sister_val }
        @current_keys[req_key.to_sym] = req_val
      end
    end
  end

  def build_config(mpp)
    config = load_root_config_yaml_file(mpp)
    config[:apply] = load_version_config_yaml_file(mpp).try(:[], :apply)
    config.dig(:apply, :page_templates) && config[:apply][:page_templates].each do |page|
      page_configs = config[:apply][:page_configs] || {}
      next if page_configs.keys.include? page
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
    actual_num_non_required_keys = object.keys - num_required_keys
    num_allowed_keys = num_required_keys + (max || actual_num_non_required_keys)
    [num_required_keys, num_allowed_keys]
  end

  def has_only_allowed_keys?(object, valid_config)
    @current_keys.merge!(valid_config[:allowed] || {})
    allowed_when = valid_config[:allowed_when]
    allowed_when && allowed_when.each do |key_to_check, conditional_values|
      value = object[key_to_check]
      conditional_values.each do |value_to_check, conditionally_allowed|
        @current_keys.merge!(conditionally_allowed) if value_to_check == value
      end
    end

    @extra_keys = object.keys - @current_keys.keys
    @extra_keys.zero?
  end

  def has_all_required_keys?(object, valid_config, parent)
    @current_keys = valid_config[:required] || {}
    add_keys_required_from_sister_to_current_keys!(parent)

    required_when = valid_config[:required_when]
    required_when && required_when.each do |key_to_check, conditional_values|
      value = object[key_to_check]
      conditional_values.each do |value_to_check, conditionally_required|
        @current_keys.merge!(conditionally_required) if value_to_check == value
      end
    end

    @missing_keys = required.keys - object.keys
    @missing_keys.zero?
  end

  def has_too_few_keys?(object, valid_config, num_allowed_keys)
    min = valid_config[:min]
    return false if min && (num_allowed_keys < min)
    true
  end

  def has_too_many_keys?(object, valid_config, num_allowed_keys)
    max = valid_config[:max]
    return false if max && (num_allowed_keys > max)
    true
  end

  def is_class_valid?(object, valid_config)
    expected = valid_config[:object_class]
    actual = object.class

    if actual.to_s != expected
      raise InvalidClassError, "Expected: #{expected} Actual: #{actual}", object_trace
    elsif !SUPPORTED_CLASSES.include? actual
      raise UnsupportedClassError, "#{actual} class not supported", object_trace
    end
  end

  def is_hash_valid?(object:, valid_config:, object_name:, object_trace:, parent:)
    # Note: the order of these checks is important as keys are added to 
    #   @current_keys for use at various points through the process
    unless has_all_required_keys?(object, valid_config, parent)
      raise MissingRequiredParameterError, "#{object_name} is missing required parameter(s): #{@missing_keys.join(', ')}", object_trace
    end

    mun_required_keys, num_allowed_keys = calculate_required_and_allowed_key_numbers(object, valid_config)
    actual_num_keys = object.keys.length

    if has_too_many_keys?(object, valid_config, num_allowed_keys)
      raise TooManyParametersError, "#{object_name} only allows #{num_allowed_keys} parameters, but found #{actual_num_keys}", object_trace
    end

    if has_too_few_keys?(object, valid_config, num_required_keys)
      raise TooFewParametersError, "#{object_name} requires #{num_required_keys} parameters, but found #{actual_num_keys}", object_trace
    end

    unless has_only_allowed_keys?(object, valid_config)
      raise InvalidParameterError, "#{object_name} does not allow these parameter(s): #{@extra_keys.join(', ')}", object_trace
    end

    object.keys.each do |key, value_config|
      next_data_type = @current_keys[key]
      case next_data_type
      when Symbol

      is_valid? object: value_config
        object_data_type: 
        object_name: key,
        object_trace: object_trace,
        parent_object: object
    end
  end

  def is_array_valid?(object:, valid_config:, object_name:, object_trace:)
    # handle value_types, allowed, allowed_min/_max
    true
  end

  def is_string_valid?(object, valid_config, object_name, object_trace)
    # handle validations: Array of { type, parameters }
    true
  end

  def load_root_config_yaml_file(mpp)
    begin
      file_path = File.join(@root_path,
        @config_path,
        mpp.to_s,
        'config.yml')
      puts file_path
      YAML.load_file(file_path).with_indifferent_access 
    rescue StandardError => e
      raise RootConfigNotFoundError, "Missing root config.yml for #{mpp}"
    end
  end

  def load_version_config_yaml_file(mpp)
    # TODO account for different active versions
    begin
      file_path = File.join(@root_path,
        @config_path,
        mpp.to_s,
        'v',
        '1',
        'version_config.yml')
      puts file_path
      YAML.load_file(file_path).with_indifferent_access 
    rescue StandardError => e
      raise VersionConfigNotFoundError, "Missing v1 version_config.yml for #{mpp}"
    end
  end

  def load_page_config_yaml_file(mpp, page)
    begin
      file_path = File.join(@root_path,
        @config_path,
        mpp.to_s,
        'v',
        '1',
        'stage_variants',
        page,
        'page_config.yml')
      puts file_path
      YAML.load_file(file_path).with_indifferent_access 
    rescue StandardError => e
      raise PageConfigNotFoundError, "Missing #{page} page_config.yml for #{mpp}"
    end
  end

  def update_object_trace(object_trace, object_name)
    # root config is handled with start_evaluate naming
    if object_name == :apply
      object_trace.pop
      object_to_add = [:v, :'1', :'version_config.yml']
    elsif object_trace.last == :page_configs && !PAGES_WITHOUT_DIRS.include?(:object_name)
      object_trace.pop
      object_to_add = [:v, :'1', :stage_variantes, :personal, :'page_config.yml']
    else
      object_to_add = [object_name]
    end
    object_trace = object_trace + object_to_add
  end
end
