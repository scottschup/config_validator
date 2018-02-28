class ConfigValidator
  class Compiler
    using ::CoreRefinements

    MPPS = %i(us_avantcredit_installment us_avantcredit_credit_card us_eloan_installment)
    SUPPORTED_CLASSES = [Array, Hash, String, Fixnum]

    def initialize(market_partner_product: '',
                   config_path: 'config/customer_application',
                   root_path: nil)
      @market_partner_product = market_partner_product.to_sym
      @config_path = config_path
      @root_path = root_path || (::Rails.root rescue Dir.pwd)
    end

    def build_config(mpp)
      config = load_root_config_yaml_file(mpp)
      config[:apply] = load_version_config_yaml_file(mpp).dig(:apply) || {}
      config.dig(:apply, :page_templates) && config[:apply][:page_templates].each do |page|
        page_configs = config[:apply][:page_configs] || {}
        next if page_configs.keys.include?(page.to_sym)
        page_configs[page] = load_page_config_yaml_file(mpp, page)
      end
      { mpp.to_sym => config }
    end

    def build_all_configs
      # MPP == market_partner_product
      MPPS.inject({}) { |agg, mpp| agg.merge!(build_config(mpp)); agg }
    end

    def compiled_configs
      return build_config(@market_partner_product) unless @market_partner_product.empty?
      build_all_configs
    end

    def configs_to_test
      @configs_to_test ||= compiled_configs
    end

    def load_root_config_yaml_file(mpp)
      file_path = File.join(@root_path,
        @config_path,
        mpp.to_s,
        'config.yml')
      puts "Loading:".colorize(:yellow) + " #{file_path}"
      YAML.load_file(file_path).deep_symbolize_keys 
    rescue StandardError => e
      raise RootConfigNotFoundError.new "Missing root config.yml for #{mpp.to_s.colorize(:light_white)}"
    end

    def load_version_config_yaml_file(mpp)
      # TODO account for different active versions
      file_path = File.join(@root_path,
        @config_path,
        mpp.to_s,
        'v',
        '1',
        'version_config.yml')
      puts "Loading:".colorize(:yellow) + " #{file_path}"
      YAML.load_file(file_path).deep_symbolize_keys
    rescue StandardError => e
      raise VersionConfigNotFoundError.new "Missing #{'.../v/1/version_config.yml'.colorize(:light_white)} for #{mpp}"
    end

    def load_page_config_yaml_file(mpp, page)
      file_path = File.join(@root_path,
        @config_path,
        mpp.to_s,
        'v',
        '1',
        'stage_variants',
        page,
        'page_config.yml')
      puts "Loading:".colorize(:yellow) + " #{file_path}"
      YAML.load_file(file_path).deep_symbolize_keys
    rescue StandardError => e
      if e.message.include? 'No such file'
        raise PageConfigNotFoundError.new "Missing #{('../' + page + '/page_config.yml').colorize(:light_white)} for #{mpp}"
      else
        raise StandardError, e
      end
    end

  end
end