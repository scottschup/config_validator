class ConfigValidator
  class ArrayValidator < ObjectValidatorBase
    def initialize(*args)
      super args
    end

    def is_valid?
      # handle value_types, allowed, allowed_min/_max
      true
    end

  end
end