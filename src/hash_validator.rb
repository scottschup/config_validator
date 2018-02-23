class HashValidator < ObjectValidator
  def initialize(*args)
    super(args)
  end

  def is_valid?
    super
    # Note: the order of these checks is important as keys are added to 
    #   @current_params[object_data_type] for use at various points through the process
    unless has_all_required_keys?
      raise MissingRequiredParameterError.new "#{@object_name} is missing required parameter(s): #{@missing_keys.join(', ')}", { trace: @object_trace }
    end

    unless has_only_allowed_keys?
      raise InvalidParameterError.new "#{@object_name} does not allow these parameter(s): #{@extra_keys.join(', ')}", { trace: @object_trace }
    end

    @object.each do |next_object_name, next_object|
      next_data_type = @current_params[@object_data_type][next_object_name.to_sym]
      binding.pry if ![Symbol, String].include?(next_data_type.class)

      case next_data_type
      when Symbol
        new_validator = "#{next_data_type}Validator".constantize.new(
          object: next_object,
          object_data_type: next_data_type,
          object_name: next_object_name,
          object_trace: object_trace,
          parent_object: object)
        new_validator.is_valid?
      when String
        next_actual_class = next_object.class
        unless next_actual_class == next_data_type
          update_object_trace! object_name: next_object_name
          raise InvalidClassError.new "Expected: #{next_data_type}; Actual: #{actual_class}", { trace: object_trace }
        end
      else
        raise ConfigValidatorError.new "Invalid next_data_type. Expected: Symbol or String; Actual class: #{actual_class}, value: #{next_data_type}", { trace: object_trace }
      end
    end
  end

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

end