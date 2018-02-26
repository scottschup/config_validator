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
      puts ConfigValidator.printable_object_trace("Validating: ", @object_trace)

      case @object_data_type
      when String
        @expected_classes = [@object_data_type]
        return is_class_supported? && is_class_valid?
      when Symbol
        @valid_config = DATA_TYPES[@object_data_type]
        unless @valid_config
          err_msg = "'#{@object_data_type}' is missing from data_types.yml\n"
          raise MissingDataTypeError.new err_msg, { trace: @object_trace }
        end

        @expected_classes = @valid_config[:object_classes] || [@valid_config[:object_class]]
        if @expected_classes.any?(&:nil?)
          err_msg = "#{@object_name} config is missing the parameter :object_class or :object_classes in "
          raise MissingObjectClassError.new err_msg, { trace: @object_trace }
        end
        is_class_valid?
      else
        err_msg = "Expected: String or Symbol; Actual: '#{@actual_class}'\n"
        raise InvalidClassError.new err_msg, { trace: @object_trace }
      end
    end

    private

    def next_object_is_valid?
      # Requires @next_object and @next_data_type to be set
      not_set = []
      %i(@next_object @next_data_type).each do |ivar|
        not_set << ivar unless defined?(instance_variable_get(ivar))
      end
      unless not_set.empty?
        err_msg = "The following instance variables are not set: '#{not_set.join(', ')}'\n"
        raise MissingInstanceVariableError.new err_msg, { trace: @object_trace }
      end
      next_actual_class = @next_object.class

      case @next_data_type
      when Symbol
        new_validator_class = @next_data_type == :boolean ?
          'ObjectValidatorBase' :
          "#{next_actual_class}Validator"

        new_validator = "ConfigValidator::#{new_validator_class}".constantize.new(
          object: @next_object,
          object_data_type: @next_data_type,
          object_name: @next_object_name || @next_data_type,
          object_trace: @object_trace,
          parent_object: @object)

        new_validator.is_valid?
      when String
        unless next_actual_class == @next_data_type.constantize
          update_object_trace! object_name: next_object_name
          raise InvalidClassError.new "Expected: #{@next_data_type}; Actual: #{next_actual_class}", { trace: @object_trace }
        end
        true
      else
        err_msg = "Invalid @next_data_type. Expected: Symbol or String; Actual class: '#{next_actual_class}', value: '#{@next_data_type}'\n"
        raise ConfigValidatorError.new err_msg, { trace: @object_trace }
      end
    end

    def is_class_supported?
      SUPPORTED_CLASSES.include? @actual_class
    end

    def is_class_valid?
      @expected_classes.map! { |klass| binding.pry if klass.nil?; klass.class == Class ? klass : klass.constantize }
      unless @expected_classes.include? @actual_class
        err_msg = "Expected: '#{@expected_classes.join(' or ')}'; Got: '#{@actual_class}'\n"
        raise InvalidClassError.new err_msg, { trace: @object_trace }
      end
      true
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