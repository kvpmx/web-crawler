require 'json'
require 'yaml'
require 'erb'

module Application
  # Load and parse configuration data from YAML files
  class AppConfigLoader
    class << self
      attr_reader :conf, :loaded_files

      SYSTEM_LIBS = %w[json yaml erb logger fileutils].freeze

      # Main method for loading configuration
      # @param config_path [String] Path to the main configuration file
      def config(config_path)
        # Load main configuration file
        @conf = load_default_config(config_path)

        configs_directory = @conf['yaml_dir']

        # Load additional configuration files from directory if provided
        return unless configs_directory && Dir.exist?(configs_directory)

        additional_configs = load_config(configs_directory)
        @conf = merge_configs(@conf, additional_configs)
      end

      # Load system and local libraries
      # @param libs_directory [String] Directory path containing Ruby library files (default: 'lib')
      def load_libs(libs_directory = 'lib')
        @loaded_files ||= []

        # Load system libraries
        SYSTEM_LIBS.each do |lib|
          require lib
          @loaded_files << lib unless @loaded_files.include?(lib)
        rescue LoadError => e
          puts "Warning: Could not load system library '#{lib}': #{e.message}"
        end

        # Load local libs
        return unless Dir.exist?(libs_directory)

        ruby_files = Dir.glob(File.join(libs_directory, '**', '*.rb'))

        ruby_files.each do |file_path|
          # Get relative path for tracking
          relative_path = File.expand_path(file_path)

          # Skip if already loaded
          next if @loaded_files.include?(relative_path)

          begin
            require_relative relative_path
            @loaded_files << relative_path
          rescue LoadError, StandardError => e
            puts "Warning: Could not load '#{file_path}': #{e.message}"
          end
        end
      end

      # Pretty print configuration data in JSON format
      def pretty_print_config_data
        if @conf
          puts JSON.pretty_generate(@conf)
        else
          puts 'No configuration data loaded'
        end
      end

      private

      # Load main configuration file with ERB and YAML processing
      # @param path [String] Path to the configuration file
      # @return [Hash] Parsed configuration data
      def load_default_config(path)
        raise "Configuration file not found: #{path}" unless File.exist?(path)

        conf_text = File.read(path)
        erb = ERB.new(conf_text)
        processed_text = erb.result

        YAML.safe_load(processed_text) || {}
      rescue StandardError => e
        raise "Error loading configuration from #{path}: #{e.message}"
      end

      # Load all YAML files from specified directory and merge them
      # @param directory [String] Directory path containing YAML files
      # @return [Hash] Merged configuration data from all YAML files
      def load_config(directory)
        config_data = {}

        yaml_files = Dir.glob(File.join(directory, '*.{yml,yaml}'))

        yaml_files.each do |file_path|
          file_content = File.read(file_path)
          file_config = YAML.safe_load(file_content) || {}

          # Use filename (without extension) as key
          filename = File.basename(file_path, '.*')
          config_data[filename] = file_config
        rescue StandardError => e
          puts "Warning: Error loading #{file_path}: #{e.message}"
        end

        config_data
      end

      # Merge configuration hashes
      # @param base_config [Hash] Base configuration
      # @param additional_config [Hash] Additional configuration to merge
      # @return [Hash] Merged configuration
      def merge_configs(base_config, additional_config)
        base_config.merge(additional_config) do |_key, base_val, additional_val|
          if base_val.is_a?(Hash) && additional_val.is_a?(Hash)
            merge_configs(base_val, additional_val)
          else
            additional_val
          end
        end
      end
    end
  end
end
