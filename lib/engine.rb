module Application
  # Engine class responsible for managing the application execution flow
  class Engine
    attr_reader :config

    # Initialize the Engine with configuration
    def initialize
      @config = {}
      @database_connector = nil
      @parsed_items = nil
    end

    # Load configuration from YAML file
    def load_config(config_file_path = 'config/application.yaml')
      @config = YAML.load_file(config_file_path)
      puts "Configuration loaded successfully from #{config_file_path}"
      LoggerManager.log_processed_file(config_file_path, 'SUCCESS', 'Configuration loaded')
      true
    rescue StandardError => e
      error_message = "Failed to load configuration from #{config_file_path}: #{e.message}"
      puts error_message
      LoggerManager.log_error(error_message, e, 'load_config')
      false
    end

    # Execute methods based on configuration parameters
    def run_methods(config_params)
      return unless config_params.is_a?(Hash)

      config_params.each do |method_name, enabled|
        next unless enabled.to_i.positive?

        method_symbol = method_name.to_sym
        if respond_to?(method_symbol, true)
          begin
            puts "Executing method: #{method_name}"
            LoggerManager.log_processed_file(method_name, 'STARTED', 'Method execution started')
            send(method_symbol)
            LoggerManager.log_processed_file(method_name, 'SUCCESS', 'Method execution completed')
          rescue StandardError => e
            error_message = "Failed to execute method #{method_name}: #{e.message}"
            puts error_message
            LoggerManager.log_error(error_message, e, 'run_methods')
          end
        else
          warning_message = "Method #{method_name} not found or not implemented"
          puts warning_message
          LoggerManager.log_processed_file(method_name, 'WARNING', warning_message)
        end
      end
    end

    # Main run method that orchestrates the entire process
    def run(config_params)
      puts 'Starting Engine execution...'

      # Load configuration
      unless load_config
        puts 'Failed to load configuration. Aborting execution.'
        return false
      end

      # Initialize logging
      initialize_logging

      # Connect to database
      connect_to_database

      # Execute methods based on configuration
      run_methods(config_params)

      # Archive created files
      archive_files

      # Close database connection
      close_database_connection

      puts 'Engine execution completed.'
      LoggerManager.log_processed_file('Engine', 'SUCCESS', 'Execution completed successfully')
      true
    rescue StandardError => e
      error_message = "Engine execution failed: #{e.message}"
      puts error_message
      LoggerManager.log_error(error_message, e, 'run')
      false
    end

    # Run website parser
    def run_website_parser
      puts 'Running website parser...'
      crawler_config = AppConfigLoader.conf&.dig('crawler') || {}

      parser = SimpleWebsiteParser.new(crawler_config)
      @parsed_items = parser.start_parse

      puts "Website parsing completed. Collected #{@parsed_items&.count || 0} items."
    end

    # Save data to CSV format
    def run_save_to_csv
      return unless @parsed_items

      output_file = 'output/items.csv'
      @parsed_items.save_to_csv(output_file)
      puts "Data saved to CSV: #{output_file}"
    end

    # Save data to JSON format
    def run_save_to_json
      return unless @parsed_items

      output_file = 'output/items.json'
      @parsed_items.save_to_json(output_file)
      puts "Data saved to JSON: #{output_file}"
    end

    # Save data to YAML format
    def run_save_to_yaml
      return unless @parsed_items

      output_dir = 'output/yaml'
      @parsed_items.save_to_yml(output_dir)
      puts "Data saved to YAML files in: #{output_dir}"
    end

    # Save data to SQLite database
    def run_save_to_sqlite
      return unless @parsed_items && @database_connector

      begin
        @database_connector.save_items_to_sqlite(@parsed_items)
        puts 'Data saved to SQLite database'
      rescue StandardError => e
        puts "Failed to save to SQLite: #{e.message}"
        LoggerManager.log_error('Failed to save to SQLite', e, 'run_save_to_sqlite')
      end
    end

    # Save data to MongoDB database
    def run_save_to_mongodb
      return unless @parsed_items && @database_connector

      begin
        @database_connector.save_items_to_mongodb(@parsed_items)
        puts 'Data saved to MongoDB database'
      rescue StandardError => e
        puts "Failed to save to MongoDB: #{e.message}"
        LoggerManager.log_error('Failed to save to MongoDB', e, 'run_save_to_mongodb')
      end
    end

    private

    # Initialize logging system
    def initialize_logging
      LoggerManager.init
      puts 'Logging initialized.'
    rescue StandardError => e
      puts "Failed to initialize logging: #{e.message}"
    end

    # Connect to database
    def connect_to_database
      database_config = AppConfigLoader.conf&.dig('database')
      return unless database_config

      @database_connector = DatabaseConnector.new(database_config)
      @database_connector.connect_to_database
      puts 'Connected to database.'
    rescue StandardError => e
      puts "Failed to connect to database: #{e.message}"
      LoggerManager.log_error('Failed to connect to database', e, 'connect_to_database')
    end

    # Close database connection
    def close_database_connection
      return unless @database_connector

      @database_connector.close_connection
      puts 'Database connection closed.'
    rescue StandardError => e
      puts "Failed to close database connection: #{e.message}"
      LoggerManager.log_error('Failed to close database connection', e, 'close_database_connection')
    end

    # Archive created files
    def archive_files
      output_dir = 'output'
      archive_name = "web_crawler_results_#{Time.now.strftime('%Y%m%d_%H%M%S')}.zip"
      archive_path = File.join(output_dir, archive_name)

      return unless Dir.exist?(output_dir)

      begin
        Zip::File.open(archive_path, Zip::File::CREATE) do |zipfile|
          Dir.glob("#{output_dir}/**/*").each do |file|
            next if file == archive_path || File.directory?(file)

            zipfile.add(file.sub("#{output_dir}/", ''), file)
          end
        end

        puts "Files archived to: #{archive_path}"
        LoggerManager.log_processed_file(archive_path, 'SUCCESS', 'Files archived')

        # Send archive via email in background
        ArchiveSender.perform_async(archive_path, 'user@example.com') # TODO: Get email from config
      rescue StandardError => e
        puts "Failed to create archive: #{e.message}"
        LoggerManager.log_error('Failed to create archive', e, 'archive_files')
      end
    end
  end
end
