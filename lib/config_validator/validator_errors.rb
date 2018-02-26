class ConfigValidator
  class ValidatorError < ConfigError; end
  class MissingDataTypeError < ValidatorError; end
  class MissingObjectClassError < ValidatorError; end
  class MissingInstanceVariableError < ValidatorError; end
end
