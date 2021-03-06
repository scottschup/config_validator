class ConfigValidator
  class ArrayValidator < ObjectValidatorBase
    def initialize(*args)
      super
    end

    def valid?
      super
      unless has_only_allowed_values?
        return false if @just_checking
        err_msg = "'#{@invalid_value.colorize(:cyan)}' is not an allowed value.\n (#{ConfigValidator.class_eval '@@objects.keys.length'})"
        err = (InvalidValueError.new err_msg, { trace: @object_trace, object: @object })
        ConfigValidator.class_eval '@@errors << err'
      end

      unless has_correct_number_of_elements?
        return false if @just_checking
        err_msg = "'#{@object_name.to_s.colorize(:cyan)} (type: #{@object_data_type.to_s.colorize(:cyan)})' has an invalid number of elements. (#{ConfigValidator.class_eval '@@objects.keys.length'})"
        err_msg += "\nExpected between #{@expected_range[:min].to_s.colorize(:light_white).bold} and #{@epxected_range[:max].to_s.colorize(:light_white).bold}, but got #{@actual_array_length.to_s.colorize(:cyan)}.\n"
        err = (InvalidNumberOfElementsError.new err_msg, { trace: @object_trace, object: @object })
        ConfigValidator.class_eval '@@errors << err'
      end

      return true unless @valid_config[:value_types]
      @object.each do |element|
        next if is_an_allowed_value_type?(element)
        return false if @just_checking
        err_msg = "#{@next_data_type.to_s.colorize(:cyan)} is not a valid data type for #{@object_name.to_s.colorize(:light_white).bold} (#{ConfigValidator.class_eval '@@objects.keys.length'})"
        err = (InvalidValueType.new err_msg, { trace: @object_trace, object: @object })
        ConfigValidator.class_eval '@@errors << err'
      end
    end

    private

    def has_only_allowed_values?
      return true unless (allowed = @valid_config[:allowed])
      @object.all? do |element|
        is_allowed = allowed.include? element
        @invalid_value = is_allowed ? nil : element
        is_allowed
      end
    end

    def has_correct_number_of_elements?
      @actual_array_length = @object.length
      min = @valid_config[:allowed_min] || 0
      max = @valid_config[:allowed_max] ||
        @valid_config[:allowed].try(:length) ||
        @actual_array_length
      @expected_range = { min: min, max: max }

      @too_few = @actual_array_length < min
      @too_many = @actual_array_length > max
      !(@too_few || @too_many)
    end

    def is_an_allowed_value_type?(element)
      @next_object = element
      @just_checking = true
      result = @valid_config[:value_types].any? do |next_data_type|
        @next_data_type = next_data_type
        next_object_valid?
      end
      @just_checking = false
      result
    end

  end
end
