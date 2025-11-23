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

    # BookItem usage demo
    test_book_item
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

  def self.test_book_item
    # Create a BookItem with block configuration
    item = BookItem.new(title: 'Book 1', price: 150, image_path: './images/book1.jpg') do |book|
      book.description = 'Description 1'
      book.category = 'Category 1'
      book.availability = true
      book.product_info = { author: 'Author 1' }
    end

    puts "\nBook 1:"
    puts "\nString representation:", item.info

    # Update attributes via block
    item.update do |i|
      i.title = 'New book'
      i.price = 100
    end

    puts "\nHash representation:", item.to_h
    puts "\nInspect:", item.inspect

    # Generate fake item
    fake_item = BookItem.generate_fake
    puts "\nBook 2:", fake_item

    # Comparison
    comparison = item <=> fake_item
    puts "\nComparison by price (item <=> fake_item): #{comparison}"
  end
end

Application.start if __FILE__ == $PROGRAM_NAME
