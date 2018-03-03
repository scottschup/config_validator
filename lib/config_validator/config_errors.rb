class ConfigValidator
  class ConfigError < StandardError
    def initialize(message = '', error_hash = {})
      if object_trace = error_hash[:trace]
        super "#{ConfigValidator.printable_object_trace(message, object_trace, error_hash[:object])}\n"
      else
        super "#{message}\n"
      end
    end
  end

  class RootConfigNotFoundError < ConfigError; end
  class VersionConfigNotFoundError < ConfigError; end
  class PageConfigNotFoundError < ConfigError; end
  class PageLoadError < ConfigError; end

  class InvalidConfigVersionError < ConfigError; end
  class InvalidClassError < ConfigError; end
  class UnsupportedClassError < ConfigError; end

  class MissingRequiredParameterError < ConfigError; end
  class TooFewParametersError < ConfigError; end
  class TooManyParametersError < ConfigError; end
  class InvalidParameterError < ConfigError; end
  class UnsupportedValidationTypeError < ConfigError; end

  class InvalidValueError < ConfigError; end
  class InvalidValueType < ConfigError; end
  class InvalidNumberOfElementsError < ConfigError; end
end
