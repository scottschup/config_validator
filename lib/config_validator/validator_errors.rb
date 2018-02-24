class ConfigValidator
  class ValidatorError < ConfigError
    def initialize(message, error_hash)
      location = error_hash[:location]
      error_hash.delete :location if location
      super(message, error_hash)
      puts location
    end
  end

  class MissingDataTypeError < ValidatorError; end
end
