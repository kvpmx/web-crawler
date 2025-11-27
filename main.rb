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

    # Cart usage demo
    test_cart

    # Configurator demo
    test_configurator

    # DatabaseConnector demo
    test_database_connector
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

  def self.test_cart
    cart = Cart.new

    # Generate and display items
    cart.generate_test_items(5)
    puts "\nCart class info:", Cart.class_info
    puts "\nTotal price:", cart.total_price
    puts "\nAll available?:", cart.all_available?
    puts "\nUnique categories:", cart.unique_categories.inspect

    first_expensive = cart.find_item { |i| i.price.to_f > 50 }
    puts "\nFirst item with price > 50:\n#{first_expensive}"

    # Demo for `method_missing`
    puts "\nAll items:"
    cart.show_all_items

    # Persistence
    out_dir = 'output'
    cart.save_to_file(File.join(out_dir, 'items.txt'))
    cart.save_to_json(File.join(out_dir, 'items.json'))
    cart.save_to_csv(File.join(out_dir, 'items.csv'))
    cart.save_to_yml(File.join(out_dir, 'yaml'))
  end

  def self.test_configurator
    configurator = Configurator.new(run_save_to_json: 1)

    puts "\nConfigurator initial config:", configurator.config

    configurator.configure(
      run_website_parser: 1,
      run_save_to_csv: 1,
      run_save_to_yaml: 1,
      run_save_to_sqlite: 1,
      run_unknown_handler: 1
    )

    puts "\nConfigurator updated config:", configurator.config
    puts "\nAvailable config keys:", Configurator.available_methods

    actions = {
      run_website_parser: -> { puts 'Running website parser...' },
      run_save_to_csv: -> { puts 'Exporting data to CSV...' },
      run_save_to_yaml: -> { puts 'Exporting data to YAML...' },
      run_save_to_sqlite: -> { puts 'Persisting data to SQLite...' },
      run_save_to_mongodb: -> { puts 'Persisting data to MongoDB...' }
    }

    puts "\nExecuting enabled actions:"
    configurator.run_actions(actions)
  end

  def self.test_database_connector
    puts "\n=== DatabaseConnector Test ==="

    # Get database configuration
    database_config = AppConfigLoader.conf['database']

    # Test SQLite connection
    puts "\nTesting SQLite connection..."
    begin
      sqlite_connector = DatabaseConnector.new(database_config)
      sqlite_connector.connect_to_database

      puts '[OK] Successfully connected to SQLite database'
      puts "  Database file: #{database_config['sqlite_database']['db_file']}"

      sqlite_connector.close_connection
      puts '[OK] Successfully closed SQLite connection'
    rescue StandardError => e
      puts "[ERR] SQLite connection failed: #{e.message}"
    end

    # Test MongoDB connection
    puts "\nTesting MongoDB connection..."
    begin
      mongodb_config = database_config.dup
      mongodb_config['database_type'] = 'mongodb'

      mongodb_connector = DatabaseConnector.new(mongodb_config)
      mongodb_connector.connect_to_database

      puts '[OK] Successfully connected to MongoDB database'
      puts "  URI: #{mongodb_config['mongodb_database']['uri']}"
      puts "  Database name: #{mongodb_config['mongodb_database']['db_name']}"

      mongodb_connector.close_connection
      puts '[OK] Successfully closed MongoDB connection'
    rescue StandardError => e
      puts "[ERR] MongoDB connection failed: #{e.message}"
      puts '  (This is expected if MongoDB is not running locally)'
    end

    puts "\n=== DatabaseConnector Test Complete ==="
  end
end

Application.start if __FILE__ == $PROGRAM_NAME
