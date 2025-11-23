require 'faker'

module Application
  # Class for representation parsed book item data
  class BookItem
    include Comparable

    attr_accessor :title, :description, :category, :price, :availability, :image_path, :product_info

    # Initialize with hash of attributes and optional block for configuration
    def initialize(params = {})
      @title = params.fetch(:title, 'Untitled')
      @description = params.fetch(:description, '')
      @category = params.fetch(:category, 'General')
      @price = (params.fetch(:price, 0.0) || 0).to_f
      @availability = params.fetch(:availability, false)
      @image_path = params.fetch(:image_path, '')
      @product_info = params.fetch(:product_info, {})

      yield self if block_given?

      LoggerManager.log_processed_file('BookItem', 'SUCCESS', "Initialized: title='#{@title}', price=#{@price}")
    end

    # Update attributes via block, returns self
    def update
      return self unless block_given?

      yield self

      LoggerManager.log_processed_file('BookItem#update', 'SUCCESS', "Updated: title='#{@title}', price=#{@price}")

      self
    end

    # Comparable: compare by price
    def <=>(other)
      return nil unless other.respond_to?(:price)

      price.to_f <=> other.price.to_f
    end

    # Hash representation built dynamically from instance variables
    def to_h
      instance_variables.each_with_object({}) do |ivar, hash|
        key = ivar.to_s.delete('@').to_sym
        hash[key] = instance_variable_get(ivar)
      end
    end

    # String representation with error handling and logging
    def to_s
      attrs = to_h
      parts = attrs.map { |k, v| "#{k}=#{v.inspect}" }.join(', ')
      "#<BookItem #{parts}>"
    rescue StandardError => e
      LoggerManager.log_error('Error generating info for BookItem', e, 'BookItem#to_s')
      "#<BookItem error: #{e.class}: #{e.message}>"
    end

    # Developer-friendly inspect output
    def inspect
      to_h.pretty_inspect
    end

    # Generate a fake book item
    def self.generate_fake
      product_info = {
        author: Faker::Book.author,
        publisher: Faker::Book.publisher,
        isbn: Faker::Code.isbn
      }

      new(
        title: Faker::Book.title,
        description: Faker::Lorem.paragraph(sentence_count: 2),
        category: Faker::Book.genre,
        price: Faker::Commerce.price(range: 5.0..150.0, as_string: false),
        availability: [true, false].sample,
        image_path: Faker::File.file_name(dir: '/images', ext: 'jpg'),
        product_info: product_info
      )
    end

    alias info to_s
  end
end
