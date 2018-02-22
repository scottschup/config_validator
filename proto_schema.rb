# Schema
# * == required

# `customer_application/{locale}_{owner}_{product}/config.yml`
# :product_config
* active_versions: { Array => [Fixnum] }

# `customer_application/{locale}_{owner}_{product}/v/{version_number}/version_config.yml`
# :version_config
* apply:
    additional_templates: { Array => [String] } # avant-basic file names
*   assets:
*     scripts:
*       apply: { Array => String } # manifest file names
*       basic: { Array => String } # avant-basic file names
*     styles: { Array => String } # manifest file names
    include:
      threat_matrix: :boolean
    layout: String
    modals: { Array => :file_name }
*   page_templates: { Array => :stage_variant }
*   ruby_eval: { Hash => String } # ruby-evaluatable expressions
    shared_configs: { Hash => :component_config }
*   page_configs: { Hash => Hash }
      declined: { Hash => :page_config }
      home: { Hash => :page_config }
      service_failure: { Hash => :page_config }

# `customer_application/{locale}_{owner}_{product}/v/{version_number}/stage_variants/{stage_name}/page_config.yml`
# :page_config
* layout: <string; `customer_application_renderer/layouts` layout name>
* components:
  component_configs:
    header:
      sections: <array: :header_section>
    form:
      form_elements: <array: :form_element>
    rates_and_terms:
    contract:
    footer:
    sidebar:

# :header_variant
  title:
    attrs: Hash
*   text: String
  subtitle:
    attrs: Hash
*   text: String
  disclaimer:
    attrs: Hash
*   text: String
  post_header:
    attrs: Hash
*   text: String

# :form_element
  element_type: [:fieldset, :]
  stackable: [TrueClass, FalseClass]
* form_rows: <array: :form_row>

# :form_row
  row_label:
*   text: String
    for: String
    sublabel: { Hash => String }
*     text: String
...

# :form_group
* field_options: { Hash => [Hash, String, Array, :boolean] }
  field_type: String

# :checkbox_input
* field_options:
*   object_name: String
*   attr_name: String
    hide_conditions: { Array => :angular_expression }
    is_padded: [:boolean, :angular_expression]
*   label: { Hash => :label }
    hidden_inputs: { Array => :hidden_input }
    use_should_hide_consent: :boolean

# :label (template, text, or array of text lines)
  attrs: <Hash: angular/html attributes>
  template:
*   text: <string; may contain %{interpolated_value}>
    data:
      interpolated_value:
        link_type: modal || url || tooltip
        link_text: <string>
        link_target: modal_name || <url>
  text: String
  text_lines: { Array => Strings }

# :hidden_input
* field_options:
*   object_name: <string>
*   attr_name: <string>
    value: <boolean|string>

# Consents
