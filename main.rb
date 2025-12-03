require_relative 'lib/app_config_loader'

# Main application entry point
module Application
  def self.run
    puts 'Starting Web Crawler Application...'

    begin
      # Step 1: Load all necessary system and developed libraries
      puts 'Loading libraries...'
      AppConfigLoader.load_libs
      puts 'Libraries loaded successfully.'

      # Step 2: Load application configuration from YAML file
      puts 'Loading configuration...'
      config_path = './config/application.yaml'
      AppConfigLoader.config(config_path)
      puts 'Configuration loaded successfully.'

      # Verify configuration was loaded
      raise 'Failed to load application configuration' unless AppConfigLoader.conf

      # Step 3: Create Configurator instance with loaded configuration
      puts 'Initializing configurator...'
      configurator = Configurator.new

      database_type = AppConfigLoader.conf['database']['database_type']

      # Get configuration parameters for the application run
      # You can override these values or load them from additional config
      run_config = {
        run_website_parser: 1,  # Enable website parsing
        run_save_to_csv: 1,     # Enable CSV export
        run_save_to_json: 1,    # Enable JSON export
        run_save_to_yaml: 1,    # Enable YAML export
        run_save_to_sqlite: database_type == 'sqlite' ? 1 : 0,  # Enable SQLite storage
        run_save_to_mongodb: database_type == 'mongodb' ? 1 : 0 # Enable MongoDB
      }

      # Configure the application with the desired parameters
      configurator.configure(run_config)
      puts 'Configurator initialized with run parameters.'

      # Step 4: Launch the application using Engine.run
      puts 'Starting Engine execution...'
      engine = Engine.new

      # Run the engine with configuration parameters
      success = engine.run(run_config)

      if success
        puts 'Application completed successfully.'
      else
        puts 'Application completed with errors. Check logs for details.'
      end
    rescue StandardError => e
      error_message = "Application startup failed: #{e.message}"
      puts error_message

      # Try to log the error if LoggerManager is available
      LoggerManager.log_error(error_message, e, 'Application.run') if defined?(LoggerManager)

      puts 'Please check your configuration and try again.'
      puts 'Stack trace:'
      puts e.backtrace.join("\n")

      exit 1
    end
  end
end

# Run the application if this file is executed directly
Application.run if __FILE__ == $PROGRAM_NAME
