module Application
  # Class for configuring the application
  class Configurator
    attr_reader :config

    DEFAULT_CONFIG = {
      run_website_parser: 0,
      run_save_to_csv: 0,
      run_save_to_json: 0,
      run_save_to_yaml: 0,
      run_save_to_sqlite: 0,
      run_save_to_mongodb: 0
    }.freeze

    def initialize(initial_values = {})
      @config = DEFAULT_CONFIG.dup
      configure(filter_allowed(initial_values))
    end

    def configure(overrides = {})
      return @config unless overrides.is_a?(Hash)

      overrides.each do |key, value|
        if @config.key?(key)
          @config[key] = value
        else
          warn_invalid_key(key)
        end
      end
      @config
    end

    def run_actions(actions = {})
      return unless actions.is_a?(Hash)

      actions.each do |key, handler|
        next unless @config.key?(key)
        next unless @config[key].to_i.positive?

        if handler.respond_to?(:call)
          handler.call
        else
          warn "Warning: Action for '#{key}' is not callable"
        end
      end
    end

    def self.available_methods
      DEFAULT_CONFIG.keys
    end

    private

    def warn_invalid_key(key)
      warn "Warning: Unknown config key '#{key}'"
    end

    def filter_allowed(values)
      return {} unless values.is_a?(Hash)

      values.each_with_object({}) do |(key, value), acc|
        acc[key] = value if DEFAULT_CONFIG.key?(key)
      end
    end
  end
end
