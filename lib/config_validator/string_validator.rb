class ConfigValidator
  class StringValidator < ObjectValidatorBase
    def initialize(*args)
      super args
    end

    def is_valid?
      # handle validations: Array of { type, parameters }
      true
    end

  end
end