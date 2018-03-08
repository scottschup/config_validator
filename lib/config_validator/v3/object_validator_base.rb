class ConfigValidator
  class ObjectValidatorBase
    def self.load_data_types!(version: nil)
      return if defined?(@@data_types) && !@@data_types.nil?
      file_path = "#{ConfigValidator.root_path}/data_types/v#{version || @@renderer_version}.yml"
      puts "Loading data types:".colorize(:light_yellow) + " #{file_path}"
      @@data_types = YAML.load_file(file_path)
    end

    def self.reload_data_types!(version: nil)
      @@data_types = nil
      load_data_types!(version)
    end

    def self.reset_shared_configs!
      @@shared_configs = nil
    end

    def initialize(object:, object_data_type:, object_name:, object_trace:, parent_object: {}, renderer_version: nil)
      @@renderer_version = renderer_version ? renderer_version : (@@renderer_version || '3.0')
      self.class.load_data_types!

      @object = object
      @object_data_type = object_data_type
      @object_name = object_name
      @object_trace = object_trace
      @parent_object = parent_object

      @just_checking ||= false
      @actual_class = @object.class
      @current_params = {}
    end

    def valid?
      update_object_trace!
      id = @object.object_id
      ConfigValidator.class_eval '@@objects[id] = true'
      # Toggle on for troubleshooting/debugging
      # status_msg = "Object #{ConfigValidator.class_eval '@@objects.keys.length'}: Validating: ".colorize(:cyan)
      # puts ConfigValidator.printable_object_trace(status_msg, @object_trace, @object)
      is_valid = true

      case @object_data_type
      when String
        # I don't think this is ever being hit
        ConfigValidator.class_eval '@@terminal_objects << { name: @object_name, data_type: @object_data_type, object: @object }'
        @expected_classes = [@object_data_type]
        return (is_class_supported? && is_class_valid?)
      when Symbol
        @valid_config = @@data_types[@object_data_type] || {}
        if @valid_config.empty?
          return false if @just_checking
          err_msg = "'#{@object_data_type.to_s.colorize(:cyan)}' is missing from #{'data_types.yml'.colorize(:magenta)} (#{ConfigValidator.class_eval '@@objects.keys.length'})\n"
          err = (MissingDataTypeError.new err_msg, { trace: @object_trace, object: @object })
          ConfigValidator.class_eval '@@errors << err'
          is_valid = false
        end
        @expected_classes = @valid_config[:object_classes] || [@valid_config[:object_class]] # the result of the latter condition may be #=> [nil]
        @expected_classes.each do |klass|
          if klass.nil?
            return false if @just_checking
            err_msg = "#{(':' + @object_name.to_s).colorize(:cyan)} config is missing the parameter #{':object_class or :object_classes'.colorize(:light_white).bold} (#{ConfigValidator.class_eval '@@objects.keys.length'})\n"
            err = (MissingObjectClassError.new err_msg, { trace: @object_trace, object: @object })
            ConfigValidator.class_eval '@@errors << err'
            is_valid = false
            next
          end
          is_valid = false unless (is_class_supported? && is_class_valid?)
        end
        is_valid
      else
        return false if @just_checking
        err_msg = "Expected: #{'String or Symbol'.colorize(:light_white).bold}; Actual: #{@actual_class.colorize(:cyan)} (#{ConfigValidator.class_eval '@@objects.keys.length'})\n"
        err = (InvalidClassError.new err_msg, { trace: @object_trace, object: @object })
        ConfigValidator.class_eval '@@errors << err'
        false
      end
    end

    private

    def boolean?(klass, data_type)
      data_type == :boolean || [TrueClass, FalseClass].include?(klass)
    end

    def next_object_valid?
      is_valid = true

      id = @next_object.object_id
      ConfigValidator.class_eval '@@objects[id] = true'

      # Requires @next_object and @next_data_type to be set
      not_set = []
      %i(@next_object @next_data_type @next_object_name).each do |ivar|
        not_set << ivar unless defined?(instance_variable_get(ivar))
      end
      unless not_set.empty?
        return false if @just_checking
        err_msg = "The following instance variables are not set: #{not_set.join(', ').colorize(:cyan)} (#{ConfigValidator.class_eval '@@objects.keys.length'})\n"
        err = (MissingInstanceVariableError.new err_msg, { trace: @object_trace, object: @object })
        ConfigValidator.class_eval '@@errors << err'
        is_valid = false
      end
      next_actual_class = @next_object.class

      case @next_data_type
      when Symbol
        new_validator_class = boolean?(next_actual_class, @next_data_type) ?
          'ObjectValidatorBase' :
          "#{next_actual_class}Validator"

        new_validator = "ConfigValidator::#{new_validator_class}".constantize.new(
          object: @next_object,
          object_data_type: @next_data_type,
          object_name: @next_object_name || @next_data_type,
          object_trace: @object_trace,
          parent_object: @object)

        is_valid && new_validator.valid?
      when String
        unless next_actual_class == @next_data_type.constantize
          return false if @just_checking
          update_object_trace! object_name: @next_object_name
          err_msg = "Expected: #{@next_data_type.colorize(:light_white).bold}; Actual: #{next_actual_class.colorize(:cyan)} (#{ConfigValidator.class_eval '@@objects.keys.length'})\n"
          err = (InvalidClassError.new err_msg, { trace: @object_trace, object: @object })
          ConfigValidator.class_eval '@@errors << err'
          is_valid = false
        end
      else
        return false if @just_checking || ConfigValidator.class_eval('!@@errors.empty? && @@errors.last.message.include?(@next_object_name.to_s)')
        err_msg = "Invalid @next_data_type for #{@next_object_name.to_s.colorize(:light_white).bold}. "
        err_msg += "Expected class to be: #{'Symbol or String'.colorize(:light_white).bold}; "
        err_msg += "Actual @next_data_type class: #{@next_data_type.class.to_s.colorize(:cyan)} (#{ConfigValidator.class_eval '@@objects.keys.length'})\n"
        err = (InvalidDataTypeError.new err_msg, { trace: @object_trace, object: @object })
        ConfigValidator.class_eval '@@errors << err'
        is_valid = false
      end
      is_valid
    end

    def is_class_supported?
      [Array, Hash, String, Fixnum].include? @actual_class
    end

    def is_class_valid?
      unless @expected_classes.include? @actual_class.to_s
        return false if @just_checking
        err_msg = "Expected: #{@expected_classes.join(' or ').colorize(:light_white).bold}; Got: #{@actual_class.to_s.colorize(:cyan)} (#{ConfigValidator.class_eval '@@objects.keys.length'})\n"
        err = (InvalidClassError.new err_msg, { trace: @object_trace, object: @object })
        ConfigValidator.class_eval '@@errors << err'
        false
      end
      true
    end

    def update_object_trace!(object_name: @object_name, config_version: 1)
      # root config is handled with start_evaluate naming
      pages_without_dirs = %i(home declined service_failure)

      if object_name == :apply
        @object_trace = [@object_trace.first]
        object_to_add = [:v, config_version, :'version_config.yml', object_name]
      elsif pages_without_dirs.include?(object_name.to_sym)
        @object_trace = @object_trace.first(3)
        object_to_add = [:'version_config.yml', :page_configs, object_name]
      elsif @object_trace.last == :page_configs && !pages_without_dirs.include?(object_name.to_sym)
        @object_trace = @object_trace.first(3)
        object_to_add = [:stage_variants, object_name, :'page_config.yml', object_name]
      else
        object_to_add = [object_name]
      end

      @object_trace += object_to_add
    end

  end
end
