class ConfigValidator
  class ObjectValidatorBase
    PAGES_WITHOUT_DIRS = %i(home declined service_failure)

    def self.load_data_types!
      return if defined?(@@data_types)
      file_path = './lib/config_validator/data_types.yml'
      puts "Loading:".colorize(:magenta) + " #{file_path}"
      @@data_types = YAML.load_file(file_path)
    end

    def self.reload_data_types!
      @@data_types = nil
      load_data_types!
    end

    def self.reset_errors!
      @@errors = []
    end

    def initialize(object:, object_data_type:, object_name:, object_trace:, parent_object: {})
      self.class.load_data_types!
      @@errors ||= []
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
      puts ConfigValidator.printable_object_trace("Validating: ".colorize(:cyan), @object_trace)

      case @object_data_type
      when String
        @expected_classes = [@object_data_type]
        return is_class_supported? && is_class_valid?
      when Symbol
        is_valid = true
        @valid_config = @@data_types[@object_data_type]
        unless @valid_config
          err_msg = "'#{@object_data_type}' is missing from data_types.yml\n"
          @@errors << (MissingDataTypeError.new err_msg, { trace: @object_trace })
          is_valid = false
        end

        @expected_classes = @valid_config[:object_classes] || [@valid_config[:object_class]]
        @expected_classes.each do |klass|
          next unless klass.nil?
          err_msg = "#{@object_name} config is missing the parameter :object_class or :object_classes in "
          @@errors << (MissingObjectClassError.new err_msg, { trace: @object_trace })
          is_valid = false
        end
        is_valid
      else
        err_msg = "Expected: String or Symbol; Actual: '#{@actual_class}'\n"
        @@errors << (InvalidClassError.new err_msg, { trace: @object_trace })
        false
      end
    end

    private

    def next_object_is_valid?
      is_valid = true
      # Requires @next_object and @next_data_type to be set
      not_set = []
      %i(@next_object @next_data_type).each do |ivar|
        not_set << ivar unless defined?(instance_variable_get(ivar))
      end
      unless not_set.empty?
        err_msg = "The following instance variables are not set: '#{not_set.join(', ')}'\n"
        @@errors << (MissingInstanceVariableError.new err_msg, { trace: @object_trace })
        is_valid = false
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

        is_valid && new_validator.is_valid?
      when String
        unless next_actual_class == @next_data_type.constantize
          update_object_trace! object_name: @next_object_name
          @@errors << (InvalidClassError.new "Expected: #{@next_data_type}; Actual: #{next_actual_class}\n", { trace: @object_trace })
          is_valid = false
        end
      else
        err_msg = "Invalid @next_data_type. Expected: Symbol or String; @next_data_type class: '#{@next_data_type.class}'\n"
        @@errors << (ValidatorError.new err_msg, { trace: @object_trace })
        is_valid = false
      end
      is_valid
    end

    def is_class_supported?
      SUPPORTED_CLASSES.include? @actual_class
    end

    def is_class_valid?
      @expected_classes.map! { |klass| binding.pry if klass.nil?; klass.class == Class ? klass : klass.constantize }
      unless @expected_classes.include? @actual_class
        err_msg = "Expected: '#{@expected_classes.join(' or ')}'; Got: '#{@actual_class}'\n"
        @@errors << (InvalidClassError.new err_msg, { trace: @object_trace })
        false
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