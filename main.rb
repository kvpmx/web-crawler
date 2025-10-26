require_relative 'lib/app_config_loader'

# Main application module
module Application
  def self.start
    # Load libraries
    AppConfigLoader.load_libs

    # Load application configuration
    AppConfigLoader.config('./config/application.yaml')
    AppConfigLoader.pretty_print_config_data

    # Initialize and test logger
    LoggerManager.init
    test_logger
  end

  def self.test_logger
    # Log processed files
    LoggerManager.log_processed_file('users.csv', 'SUCCESS', 'Processed 500 users')
    LoggerManager.log_processed_file('products.json', 'WARNING', 'Missing prices')

    # Log error with exception
    begin
      raise StandardError, 'Connection timeout'
    rescue StandardError => e
      LoggerManager.log_error('Database failed', e, 'Data sync operation')
    end

    # Log simple error
    LoggerManager.log_error('Config file missing', nil, 'Startup check')
  end
end

Application.start if __FILE__ == $PROGRAM_NAME
