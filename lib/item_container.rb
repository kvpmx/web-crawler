module Application
  # Mixin for managing a collection of items
  module ItemContainer
    def self.included(base)
      base.extend(ClassMethods)
      base.include(InstanceMethods)
    end

    # Methods added to the including class itself
    module ClassMethods
      # Return class information (name and version)
      def class_info
        version = const_defined?(:VERSION) ? const_get(:VERSION) : '1.0.0'
        { name: name, version: version }
      end

      # Track number of created instances
      def created_count
        @created_count ||= 0
      end

      def increment_created_count
        @created_count = created_count + 1
      end
    end

    # Methods available to instances
    module InstanceMethods
      # Add a single item to the collection
      def add_item(item)
        items << item
        LoggerManager.log_processed_file("#{self.class}#add_item", 'SUCCESS',
                                         "Added item: #{item}")
        self
      rescue StandardError => e
        LoggerManager.log_error('Failed to add item', e, "#{self.class}#add_item")
        self
      end

      # Remove item by object or by index (Integer)
      def remove_item(item_or_index)
        removed =
          if item_or_index.is_a?(Integer)
            items.delete_at(item_or_index)
          else
            items.delete(item_or_index) && item_or_index
          end

        LoggerManager.log_processed_file("#{self.class}#remove_item", 'SUCCESS',
                                         "Removed item: #{removed}")
        removed
      rescue StandardError => e
        LoggerManager.log_error('Failed to remove item', e, "#{self.class}#remove_item")
        nil
      end

      # Delete all items
      def delete_items
        count = items.size
        items.clear
        LoggerManager.log_processed_file("#{self.class}#delete_items", 'SUCCESS',
                                         "Cleared #{count} items")
        self
      rescue StandardError => e
        LoggerManager.log_error('Failed to clear items', e, "#{self.class}#delete_items")
        self
      end

      # Allow calling `show_all_items` via method_missing
      def method_missing(method_name, *args, &)
        if method_name.to_s == 'show_all_items'
          items.each_with_index do |item, index|
            puts "[#{index}] #{item}"
          end
          LoggerManager.log_processed_file("#{self.class}#show_all_items", 'SUCCESS',
                                           "Displayed #{items.size} items")
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        method_name.to_s == 'show_all_items' || super
      end
    end
  end
end
