require_relative 'item_container'

module Application
  # Collection of BookItem items with persistence and Enumerable helpers
  class Cart
    include Enumerable
    include ItemContainer

    VERSION = '1.0.0'.frozen?

    attr_reader :items

    def initialize(items = [])
      @items = Array(items).dup
      self.class.increment_created_count if self.class.respond_to?(:increment_created_count)
      LoggerManager.log_processed_file("#{self.class}#initialize", 'SUCCESS',
                                       "Initialized with #{items.size} items")
    rescue StandardError => e
      LoggerManager.log_error('Failed to initialize Cart', e, "#{self.class}#initialize")
      @items = []
    end

    # Enumerable
    def each(&)
      items.each(&)
    end

    # Generate fake items and add into collection
    def generate_test_items(count = 5)
      count.to_i.times { add_item(BookItem.generate_fake) }
      self
    rescue StandardError => e
      LoggerManager.log_error('Failed to generate test items', e, "#{self.class}#generate_test_items")
      self
    end

    # Persistence: save as human-readable text (one object per line)
    def save_to_file(path)
      ensure_directory(File.dirname(path))
      File.open(path, 'w') do |f|
        each { |item| f.puts(item.to_s) }
      end
      LoggerManager.log_processed_file(path, 'SUCCESS', 'Saved text file')
      path
    rescue StandardError => e
      LoggerManager.log_error('Failed to save text file', e, "#{self.class}#save_to_file")
      nil
    end

    # Persistence: save JSON array of objects
    def save_to_json(path)
      ensure_directory(File.dirname(path))
      data = map do |i|
        raw = i.respond_to?(:to_h) ? i.to_h : {}
        deep_stringify_keys(raw)
      end
      File.write(path, JSON.pretty_generate(data))
      LoggerManager.log_processed_file(path, 'SUCCESS', 'Saved JSON file')
      path
    rescue StandardError => e
      LoggerManager.log_error('Failed to save JSON file', e, "#{self.class}#save_to_json")
      nil
    end

    # Persistence: save CSV with dynamic headers merged from all items
    def save_to_csv(path)
      ensure_directory(File.dirname(path))

      rows = map do |i|
        raw = i.respond_to?(:to_h) ? i.to_h : {}
        normalize_for_csv(raw)
      end
      headers = rows.reduce([]) { |acc, h| (acc | h.keys.map(&:to_s)) }

      CSV.open(path, 'w', write_headers: true, headers: headers) do |csv|
        rows.each do |row|
          csv << headers.map { |key| row[key] }
        end
      end

      LoggerManager.log_processed_file(path, 'SUCCESS', 'Saved CSV file')
      path
    rescue StandardError => e
      LoggerManager.log_error('Failed to save CSV file', e, "#{self.class}#save_to_csv")
      nil
    end

    # Persistence: save each item as a separate YAML file in directory
    def save_to_yml(dir_path)
      ensure_directory(dir_path)
      each_with_index do |item, index|
        raw = item.respond_to?(:to_h) ? item.to_h : {}
        hash = deep_stringify_keys(raw)
        file_path = File.join(dir_path, "item_#{index + 1}.yml")
        File.write(file_path, YAML.dump(hash))
        LoggerManager.log_processed_file(file_path, 'SUCCESS', 'Saved YAML file')
      end
      dir_path
    rescue StandardError => e
      LoggerManager.log_error('Failed to save YAML files', e, "#{self.class}#save_to_yml")
      nil
    end

    # Enumerable helpers (demonstration of using common methods)
    def map_items(&)
      map(&)
    end

    def select_items(&)
      select(&)
    end

    def reject_items(&)
      reject(&)
    end

    def find_item(&)
      find(&)
    end

    def total_price
      reduce(0.0) { |sum, item| sum + (item.respond_to?(:price) ? item.price.to_f : 0.0) }
    end

    def all_available?
      all? { |i| i.respond_to?(:availability) && i.availability }
    end

    def any_available?
      any? { |i| i.respond_to?(:availability) && i.availability }
    end

    def none_in_category?(category)
      none? { |i| i.respond_to?(:category) && i.category == category }
    end

    def count_by_category(category)
      count { |i| i.respond_to?(:category) && i.category == category }
    end

    def sort_by_price(direction = :asc)
      sorted = sort_by { |i| i.respond_to?(:price) ? i.price.to_f : 0.0 }
      direction.to_s.downcase == 'desc' ? sorted.reverse : sorted
    end

    def unique_categories
      map { |i| i.respond_to?(:category) ? i.category : nil }.compact.uniq
    end

    private

    def ensure_directory(dir)
      return if dir.nil? || dir.empty?

      FileUtils.mkdir_p(dir)
    end

    # Keep nested structures for JSON/YAML but stringify keys for consistency
    def deep_stringify_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), acc|
          acc[k.to_s] = deep_stringify_keys(v)
        end
      when Array
        obj.map { |e| deep_stringify_keys(e) }
      else
        obj
      end
    end

    # For CSV: flatten nested structures to JSON strings and stringify keys
    def normalize_for_csv(hash)
      flatten_for_csv(hash)
    end

    def flatten_for_csv(obj, parent_key = nil, acc = {})
      case obj
      when Hash
        obj.each do |k, v|
          new_key = parent_key ? "#{parent_key}.#{k}" : k.to_s
          flatten_for_csv(v, new_key, acc)
        end
      when Array
        # Keep arrays as compact JSON in a single cell
        acc[parent_key.to_s] = JSON.generate(obj)
      else
        acc[parent_key.to_s] = obj
      end
      acc
    end
  end
end
