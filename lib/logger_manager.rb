module Application
  # Basic logger manager for the application
  class LoggerManager
    class << self
      attr_reader :logger

      # Initialize logger
      def init
        logging_config = AppConfigLoader.conf['logging']
        directory = logging_config['directory'] || 'logs'
        level = logging_config['level'] || 'DEBUG'
        files = logging_config['files'] || {}

        # Ensure log directory exists
        FileUtils.mkdir_p(directory)

        # Set up main application log file
        app_log_file = files['application_log'] || 'app.log'
        log_path = File.join(directory, app_log_file)

        # Create logger instance
        @logger = Logger.new(log_path)

        # Set logging level
        @logger.level = Logger.const_get(level&.upcase || 'DEBUG')

        # Set custom formatter
        @logger.formatter = proc do |severity, datetime, _program_name, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
        end

        # Store configuration for error logging
        @config = logging_config

        @logger.info("Logger initialized with level: #{level}")
      end

      # Log processed file information
      # @param filename [String] Path to the processed file
      # @param status [String] Processing status (default: 'SUCCESS')
      # @param additional_info [String] Additional information (optional)
      def log_processed_file(filename, status = 'SUCCESS', additional_info = nil)
        init unless @logger
        current_logger = @logger

        message = "File processed: #{filename} | Status: #{status}"
        message += " | Info: #{additional_info}" if additional_info

        case status.upcase
        when 'WARNING', 'WARN'
          current_logger.warn(message)
        when 'ERROR', 'FAILED'
          current_logger.error(message)
        else
          current_logger.info(message)
        end
      end

      # Log error information
      # @param error_message [String] Error message
      # @param exception [Exception] Exception object (optional)
      # @param context [String] Additional context information (optional)
      def log_error(error_message, exception = nil, context = nil)
        init unless @logger
        current_logger = @logger

        # Also log to separate error file if configured
        current_error_logger = error_logger

        # Build error message
        full_message = error_message
        full_message += " | Context: #{context}" if context

        if exception
          full_message += " | Exception: #{exception.class}: #{exception.message}"
          full_message += " | Backtrace: #{exception.backtrace&.first(5)&.join(' -> ')}" if exception.backtrace
        end

        # Log to main logger
        current_logger.error(full_message)

        # Log to error logger if available
        current_error_logger&.error(full_message)
      end

      private

      # Get or create error logger for separate error file
      def error_logger
        return @error_logger if @error_logger

        return nil unless @config && @config['files'] && @config['files']['error_log']

        directory = @config['directory'] || 'logs'
        error_log_file = @config['files']['error_log']
        error_log_path = File.join(directory, error_log_file)

        # Ensure directory exists
        FileUtils.mkdir_p(directory)

        @error_logger = Logger.new(error_log_path)
        @error_logger.level = Logger::ERROR
        @error_logger.formatter = proc do |severity, datetime, _program_name, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
        end

        @error_logger
      end
    end
  end
end
