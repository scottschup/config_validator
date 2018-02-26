class ConfigValidator
  class StringValidator < ObjectValidatorBase
    def initialize(*args)
      super
    end

    def is_valid?
      # handle validations: Array of { type, parameters }
      true
    end

  end
end
