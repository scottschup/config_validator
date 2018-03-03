class ConfigValidator
  class HashValidator < ObjectValidatorBase
    def initialize(*args)
      super
    end

    def valid?
      is_valid = super
      # Note: the order of these checks is important as keys are added to 
      #   @current_params[object_data_type] for use at various points through the process
      unless has_all_required_keys?
        return false if @just_checking
        err_msg = "#{@object_name.to_s.colorize(:cyan)} (type: #{@object_data_type.to_s.colorize(:cyan)}) is missing the following required parameters: #{@missing_keys.join(', ').colorize(:light_white).bold} (#{ConfigValidator.class_eval '@@counter'})\n"
        err = (MissingRequiredParameterError.new err_msg, { trace: @object_trace, object: @object })
        ConfigValidator.class_eval '@@errors << err'
        is_valid = false
      end

      unless has_only_allowed_keys?
        return false if @just_checking
        err_msg = "#{@object_name.to_s.colorize(:cyan)} (type: #{@object_data_type.to_s.colorize(:cyan)}) does not allow the following parameters: #{@extra_keys.join(', ').colorize(:light_white).bold} (#{ConfigValidator.class_eval '@@counter'})\n"
        err = (InvalidParameterError.new err_msg, { trace: @object_trace, object: @object })
        ConfigValidator.class_eval '@@errors << err'
        is_valid = false
      end

      @object.each do |next_object_name, next_object|
        @next_object = next_object
        @next_object_name = next_object_name.to_sym
        @next_data_type = @valid_config.dig(:allowed, :__any) ||
          @current_params[@object_data_type][@next_object_name]
        is_valid = false unless next_object_valid?
      end
      is_valid
    end

    def add_params_required_from_sister_to_current_params!
      return unless new_reqs = @valid_config[:required_from_sister]
      new_reqs.each do |new_req|
        sister_vals = @parent_object[new_req[:sister_key]]
        sister_vals.each do |sister_val|
          req_key = new_req[:req_key] % { sister_val: sister_val }
          req_val = new_req[:req_val].to_s % { sister_val: sister_val }
          @current_params[@object_data_type] ||= {}
          @current_params[@object_data_type][req_key.to_sym] = req_val.to_sym
        end
      end
    end

    def remove_shared_configs_from_current_params!
      @temp_hidden_params = {}
      return @@shared_configs = @object.dup if @object_name == :shared_configs
      if @object_name == :component_configs
        @@shared_configs.each do |shared_component_name, config|
          deleted = @current_params[@object_data_type].delete shared_component_name
          @temp_hidden_params[shared_component_name] = config unless deleted.nil?
        end
      end
    end

    def return_shared_configs_to_current_params!
      return unless @object_name == :component_configs
      @current_params[@object_data_type].merge!(@temp_hidden_params.dup)
    end

    def has_only_allowed_keys?
      return true if @valid_config.dig(:allowed, :__any)
      return true if (@valid_config[:allowed] || @valid_config[:allowed_when]).nil?
      @current_params[@object_data_type].merge!(@valid_config[:allowed] || {})
      return_shared_configs_to_current_params!

      allowed_when = @valid_config[:allowed_when]
      allowed_when && allowed_when.each do |key_to_check, conditional_values|
        value = key_to_check.to_s.include?('@') ? instance_variable_get(key_to_check) : @object[key_to_check]
        conditional_values.each do |value_to_check, conditionally_allowed|
          @current_params[@object_data_type].merge!(conditionally_allowed) if value_to_check.to_sym == value.to_sym
        end
      end

      @extra_keys = @object.keys.map(&:to_sym) - @current_params[@object_data_type].keys
      @extra_keys.length.zero?
    end

    def has_all_required_keys?
      @current_params[@object_data_type] = (@valid_config[:required] || {}).dup
      add_params_required_from_sister_to_current_params!
      remove_shared_configs_from_current_params!

      required_when = @valid_config[:required_when]
      required_when && required_when.each do |key_to_check, conditional_values|
        value = @object[key_to_check] || :''
        conditional_values.each do |value_to_check, conditionally_required|
          @current_params[@object_data_type].merge!(conditionally_required) if value_to_check.to_sym == value.to_sym
        end
      end

      @missing_keys = @current_params[@object_data_type].keys - @object.keys.map(&:to_sym)
      @missing_keys.length.zero?
    end

  end
end