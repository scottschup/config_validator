class ConfigValidator
  class ArrayValidator < ObjectValidatorBase
    def initialize(*args)
      super
    end

    def is_valid?
      # handle value_types, allowed, allowed_min/_max
      super
      unless has_only_allowed_values?
        err_msg = "'#{@invalid_value}' is not an allowed value.\n"
        raise InvalidValueError.new err_msg, { trace: @object_trace }
      end

      unless has_correct_number_of_elements?
        err_msg = "'#{@object_name} (type: #{@object_data_type})' has an invalid number of elements."
        err_msg += "\nExpected between #{@expected_range[:min]} and #{@epxected_range[:max]}, but got #{@actual_array_length}.\n"
        raise InvalidNumberOfElementsError.new err_msg, { trace: @object_trace }
      end

      return true unless @valid_config[:value_types]
      @object.all? do |element|
        element_is_an_allowed_value_type? element
      end
    end

    private

    def has_only_allowed_values?
      return true unless (allowed = @valid_config[:allowed])
      @object.all? { |element| allowed.include? element }
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

    def element_is_an_allowed_value_type?(next_object)
      @next_object = next_object
      @valid_config[:value_types].any? do |next_data_type|
        @next_data_type = next_data_type
        next_object_is_valid?
      end
    end

  end
end
