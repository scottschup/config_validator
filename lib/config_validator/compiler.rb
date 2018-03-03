class ConfigValidator
  class Compiler
    using ::CoreRefinements

    def initialize(market_partner_product: '',
                   config_path: 'config/customer_application',
                   root_path: nil,
                   config_version:)
      @mpp = market_partner_product.to_sym
      @config_path = config_path
      @root_path = root_path || (::Rails.root rescue File.dirname(__FILE__))
      @config_version = config_version
      @compiled_config = {}
    end

    def base_path
      File.join @root_path, @config_path, @mpp.to_s
    end

    def base_version_path(version = 1)
      File.join base_path, 'v', version.to_s
    end

    def build_config
      load_root_config_yaml_file!
      unless valid_active_version?
        err_msg = "Version #{@config_version} not in [#{config[:active_versions.join(', ')]}]"
        raise InvalidConfigVersionError.new err_msg
      end

      load_version_config_yaml_file!
      unless page_templates = @compiled_config.dig(@mpp, :apply, :page_templates)
      end
      page_templates.each do |page|
        page_configs = @compiled_config.dig(@mpp, :apply, :page_configs) || {}
        # skip pages that don't have their own dirs and are already in page_configs
        next if page_configs.keys.include? page.to_sym
        load_page_config_yaml_file! page
      end
    end

    def build_all_configs
      # mpp == market_partner_product
      %i(us_avantcredit_installment us_avantcredit_credit_card us_eloan_installment)
        .each { |mpp| @mpp = mpp; build_config }
    end

    def compiled_configs
      return @compiled_config unless @compiled_config.empty?
      unless @mpp.empty?
        build_config
        return @compiled_config
      end
      build_all_configs
      @compiled_config
    end

    def configs_to_test
      @compiled_configs ||= compiled_configs
    end

    def load_root_config_yaml_file!
      file_path = root_config_file_path
      print "Loading:".colorize(:yellow) + " #{file_path}..."
      @compiled_config[@mpp] = YAML.load_file(file_path).deep_symbolize_keys
      puts "DONE!".colorize(:green)
    rescue StandardError => e
      puts "FAILED :(".colorize(:red)
      raise RootConfigNotFoundError.new "Missing #{relevant_path(file_path, @mpp).colorize(:light_white)} for #{@mpp}"
    end

    def load_version_config_yaml_file!
      file_path = version_config_file_path
      print "Loading:".colorize(:yellow) + " #{file_path}..."
      version_config = YAML.load_file(file_path).deep_symbolize_keys
      @compiled_config[@mpp].merge! version_config
      puts "DONE!".colorize(:green)
    rescue StandardError => e
      puts "FAILED :(".colorize(:red)
      err_msg = "Missing #{relevant_path(file_path).colorize(:light_white)} for #{@mpp}"
      raise VersionConfigNotFoundError.new err_msg
    end

    def load_page_config_yaml_file!(page)
      file_path = page_config_file_path(page)
      print "Loading:".colorize(:yellow) + " #{file_path}..."
      page_config = YAML.load_file(file_path).deep_symbolize_keys
      @compiled_config[@mpp][:apply][:page_configs][page] = page_config
      puts "DONE!".colorize(:green)
    rescue StandardError => e
      puts "FAILED :(".colorize(:red)
      if e.message.include? 'No such file'
        err_msg = "Missing #{relevant_path(file_path).colorize(:light_white)} for #{@mpp}"
        raise PageConfigNotFoundError.new err_msg
      else
        raise e
      end
    end

    def page_config_file_path(page)
      File.join base_version_path, 'stage_variants', page, 'page_config.yml'
    end

    def relevant_path(path)
      path.split(base_path)[-1]
    end

    def root_config_file_path
      File.join base_path, 'config.yml'
    end

    def valid_active_version?
      @compiled_config.dig(@mpp, :active_versions).include?(@config_version)
    rescue false
    end

    def version_config_file_path
      File.join base_version_path, 'version_config.yml'
    end

  end
end
