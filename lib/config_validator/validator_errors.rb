class ConfigValidator
  class ValidatorError < ConfigError; end
  class InvalidDataTypeError < ValidatorError; end
  class MissingDataTypeError < ValidatorError; end
  class MissingObjectClassError < ValidatorError; end
  class MissingInstanceVariableError < ValidatorError; end
end
