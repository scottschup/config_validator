class ConfigValidator
  class ConfigError < StandardError
    def initialize(message, error_hash={})
      if trace = error_hash[:trace]
        puts message
        super trace.join(' > ')
        caller
      else
        super message
      end
    end
  end

  class RootConfigNotFoundError < ConfigError; end
  class VersionConfigNotFoundError < ConfigError; end
  class PageConfigNotFoundError < ConfigError; end
  class InvalidClassError < ConfigError; end
  class UnsupportedClassError < ConfigError; end
  class MissingRequiredParameterError < ConfigError; end
  class TooFewParametersError < ConfigError; end
  class TooManyParametersError < ConfigError; end
  class InvalidParameterError < ConfigError; end
end
