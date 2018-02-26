class ConfigValidator
  class ObjectValidatorBase
    PAGES_WITHOUT_DIRS = %i(home declined service_failure)
    DATA_TYPES = YAML.load_file('./lib/config_validator/data_types.yml')

    def initialize(object:, object_data_type:, object_name:, object_trace:, parent_object: {})
      @object = object
      @object_data_type = object_data_type
      @object_name = object_name
      @object_trace = object_trace
      @parent_object = parent_object

      @actual_class = @object.class
      @current_params = {}
    end

    def is_valid?
      update_object_trace!
      print_object_trace "Validating:"

      case @object_data_type
      when String
        @expected_classes = [@object_data_type]
        return is_class_supported? && is_class_valid?
      when Symbol
        @valid_config = DATA_TYPES[@object_data_type]
        unless @valid_config
          raise MissingDataTypeError.new "#{@object_data_type} is missing from data_types.yml", { location: 'ConfigValidator#is_valid?', trace: @object_trace }
        end

        @expected_classes = @valid_config[:object_classes] || [@valid_config[:object_class]]
        is_class_valid?
      else
        raise InvalidClassError.new "Expected: String or Symbol; Actual: #{@actual_class}", { trace: @object_trace }
      end
    end

    private

    def is_class_supported?
      SUPPORTED_CLASSES.include? @actual_class
    end

    def is_class_valid?
      @expected_classes.map! { |klass| klass.class == Class ? klass : klass.constantize }
      unless @expected_classes.include? @actual_class
        raise InvalidClassError.new "Expected: #{@expected_classes.join(' or ')}; Got: #{@actual_class}", { trace: @object_trace }
      end
      true
    end

    def print_object_trace(message)
      ellipses = @object_trace.length > 7 ? '...' : ''
      trace_string = @object_trace.last(7).join(' > ')
      divided_on_file = trace_string.split('.yml > ')
      divided_on_file[0].gsub!(' > ', '/')
      trace_with_file_division = divided_on_file.join('.yml ::: ')
      puts "#{message} #{ellipses}#{trace_with_file_division}"
    end

    def update_object_trace!(object_name: @object_name)
      # root config is handled with start_evaluate naming
      if object_name == :apply
        @object_trace = [@object_trace.first]
        object_to_add = [:v, :'1', :'version_config.yml', object_name]
      elsif PAGES_WITHOUT_DIRS.include?(object_name.to_sym)
        @object_trace = @object_trace.first(3)
        object_to_add = [:'version_config.yml', :page_configs, object_name]
      elsif @object_trace.last == :page_configs && !PAGES_WITHOUT_DIRS.include?(object_name.to_sym)
        @object_trace = @object_trace.first(3)
        object_to_add = [:stage_variants, object_name, :'page_config.yml', object_name]
      else
        object_to_add = [object_name]
      end
      @object_trace += object_to_add
    end

  end
end