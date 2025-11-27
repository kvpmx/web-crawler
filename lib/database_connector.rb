require 'sqlite3'
require 'mongo'

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

    private

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
