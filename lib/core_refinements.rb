require 'json'

# Monkey patch Hash to use deep_symbolize_keys
module CoreRefinements
  refine Hash do
    def deep_symbolize_keys
      JSON.parse(JSON[self], symbolize_names: true)
    end
  end
end
