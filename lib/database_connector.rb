module Application
  # DatabaseConnector class responsible for connecting to databases based on configuration
  class DatabaseConnector
    attr_reader :db

    # Initialize the DatabaseConnector with configuration
    # @param config [Hash] Configuration hash from YAML file
    def initialize(config)
      @config = config
      @db = nil
    end

    # Connect to the database based on configuration
    # @return [Object] Database connection object
    def connect_to_database
      database_type = @config['database_type']

      case database_type
      when 'sqlite'
        connect_to_sqlite
      when 'mongodb'
        connect_to_mongodb
      else
        raise ArgumentError, "Unsupported database type: #{database_type}. Supported types: 'sqlite', 'mongodb'"
      end

      @db
    end

    # Close the database connection if it's open
    def close_connection
      return unless @db

      @db.close if @db.respond_to?(:close)
      @db = nil
    end

    # Save items to SQLite database
    def save_items_to_sqlite(items)
      return unless @db && items

      create_items_table_sqlite if @config['database_type'] == 'sqlite'

      items.each do |item|
        save_item_to_sqlite(item)
      end
    end

    # Save items to MongoDB database
    def save_items_to_mongodb(items)
      return unless @db && items

      collection = @db[@config.dig('mongodb_database', 'collection') || 'items']

      items.each do |item|
        save_item_to_mongodb(collection, item)
      end
    end

    private

    # Create items table in SQLite
    def create_items_table_sqlite
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          description TEXT,
          category TEXT,
          price REAL,
          availability BOOLEAN,
          image_path TEXT,
          product_info TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      SQL
    end

    # Save single item to SQLite
    def save_item_to_sqlite(item)
      item_hash = item.to_h
      @db.execute(
        'INSERT INTO items (title, description, category, price, availability, image_path, product_info)' \
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          item_hash[:title],
          item_hash[:description],
          item_hash[:category],
          item_hash[:price],
          item_hash[:availability] ? 1 : 0,
          item_hash[:image_path],
          item_hash[:product_info].to_json
        ]
      )
    end

    # Save single item to MongoDB
    def save_item_to_mongodb(collection, item)
      item_hash = item.to_h
      item_hash[:created_at] = Time.now
      collection.insert_one(item_hash)
    end

    # Connect to SQLite database
    # @return [SQLite3::Database] SQLite database connection
    def connect_to_sqlite
      sqlite_config = @config['sqlite_database']
      db_file = sqlite_config['db_file']
      timeout = sqlite_config['timeout'] || 5000

      raise ArgumentError, 'SQLite database file path is required' unless db_file

      # Ensure the directory exists
      db_dir = File.dirname(db_file)
      FileUtils.mkdir_p(db_dir)

      begin
        @db = SQLite3::Database.new(db_file)
        @db.busy_timeout = timeout
        @db.results_as_hash = true # Return results as hash for easier access
      rescue SQLite3::Exception => e
        raise "Failed to connect to SQLite database '#{db_file}': #{e.message}"
      end
    end

    # Connect to MongoDB database
    # @return [Mongo::Client] MongoDB client connection
    def connect_to_mongodb
      mongodb_config = @config['mongodb_database']
      uri = mongodb_config['uri']
      db_name = mongodb_config['db_name']

      raise ArgumentError, 'MongoDB URI is required' unless uri
      raise ArgumentError, 'MongoDB database name is required' unless db_name

      begin
        @db = Mongo::Client.new(uri)
        # Test the connection
        @db.database_names
      rescue Mongo::Error => e
        raise "Failed to connect to MongoDB at '#{uri}' with database '#{db_name}': #{e.message}"
      end
    end
  end
end
