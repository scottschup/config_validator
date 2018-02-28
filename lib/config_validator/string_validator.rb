class ConfigValidator
  class StringValidator < ObjectValidatorBase
    def initialize(*args)
      super
    end

    def valid?
      is_valid = super

      if @valid_config[:allowed]
        is_valid = false unless @valid_config[:allowed].include?(@object)
      end

      (@valid_config[:validations] || []).each do |validation|
        case validation[:type]
        when :regexp
          is_valid = false unless eval(validation[:parameters]) =~ @object
        else
          err_msg = "#{validation[:type].colorize(:cyan)} is not a supported String validation type"
          @@errors << (UnsupportedValidationTypeError.new err_msg, { trace: @object_trace })
        end
      end
      is_valid
    end

  end
end
