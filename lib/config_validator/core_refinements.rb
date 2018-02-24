module CoreRefinements
  refine Hash do
    def deep_symbolize_keys
      JSON.parse(JSON[self], symbolize_names: true)
    end
  end
end
