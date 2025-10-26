require_relative 'lib/app_config_loader'

# Main application module
module Application
  def self.run
    AppConfigLoader.load_libs
    AppConfigLoader.config('./config/application.yaml')
    AppConfigLoader.pretty_print_config_data
  end
end

Application.run if __FILE__ == $PROGRAM_NAME
