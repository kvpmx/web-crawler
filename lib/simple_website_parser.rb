module Application
  # Parser responsible for collecting product data from a website
  class SimpleWebsiteParser
    DEFAULT_THREAD_POOL = 4
    DEFAULT_TIMEOUT = 10
    FALLBACK_USER_AGENT = 'Windows Chrome'.freeze

    attr_reader :config, :agent, :item_collection

    def initialize(config, agent: nil, item_collection: nil)
      @config = config || {}
      validate_config!

      @thread_pool_size = determine_thread_pool_size
      @agent = agent || build_agent
      @item_collection = item_collection || Cart.new
      @media_root = resolve_media_root
      @mutex = Mutex.new

      ensure_directory(@media_root)

      LoggerManager.log_processed_file(
        log_context('initialize'),
        'SUCCESS',
        "Initialized parser (threads=#{@thread_pool_size})"
      )
    rescue StandardError => e
      LoggerManager.log_error('Failed to initialize SimpleWebsiteParser', e, log_context('initialize'))
      raise
    end

    # Start parsing process by iterating through catalog pages
    def start_parse
      start_page_url = config.fetch('start_page')

      unless check_url_response(start_page_url)
        LoggerManager.log_error('Start page is not accessible', nil, log_context('start_parse'))
        return item_collection
      end

      current_url = start_page_url
      visited_pages = 0

      while current_url
        page = fetch_page(current_url, @agent)
        break unless page

        visited_pages += 1
        LoggerManager.log_processed_file(
          log_context('start_parse'),
          'SUCCESS',
          "Fetched listing page ##{visited_pages}: #{current_url}"
        )

        product_links = extract_products_links(page)
        parse_product_links(product_links)

        current_url = extract_next_page_link(page)
      end

      LoggerManager.log_processed_file(
        log_context('start_parse'),
        'SUCCESS',
        "Parsing finished: #{item_collection.count} items collected from #{visited_pages} pages"
      )

      item_collection
    rescue StandardError => e
      LoggerManager.log_error('Failed to parse website', e, log_context('start_parse'))
      item_collection
    end

    # Extract product links from listing page using configured selector
    def extract_products_links(page)
      selector = config['book_details_link'] || config['product_link']
      return [] unless selector && page

      page.search(selector).map do |node|
        href = node['href'] || node[:href]
        next unless href

        absolutize_url(page.uri.to_s, href)
      rescue URI::Error => e
        LoggerManager.log_error("Invalid product link: #{href}", e, log_context('extract_products_links'))
        nil
      end.compact.uniq
    end

    # Parse a single product page and add BookItem to the collection
    def parse_product_page(product_link, agent_instance = nil)
      return unless product_link

      page = fetch_page(product_link, agent_instance)
      return unless page

      category = extract_product_category(page)
      product_info = extract_product_info(page)
      availability_text = extract_product_availability_text(page)
      product_info[:availability_text] = availability_text if availability_text

      image_url = extract_product_image(page)
      image_path = save_product_image(image_url, category, agent_instance)

      item_data = {
        title: extract_product_name(page),
        description: extract_product_description(page),
        category: category,
        price: extract_product_price(page),
        availability: parse_availability_flag(availability_text),
        image_path: image_path,
        product_info: product_info
      }

      @mutex.synchronize { item_collection.add_item(BookItem.new(item_data)) }
    rescue StandardError => e
      LoggerManager.log_error("Failed to parse product page: #{product_link}", e, log_context('parse_product_page'))
      nil
    end

    # Pull product name from product page
    def extract_product_name(product_page)
      text_from_selector(product_page, config['title']) || 'Untitled'
    end

    # Pull product price as float
    def extract_product_price(product_page)
      text = text_from_selector(product_page, config['price'])
      return 0.0 unless text

      normalized = text.gsub(/[^\d.,]/, '')
      normalized.tr(',', '.').to_f
    end

    # Pull description text
    def extract_product_description(product_page)
      text_from_selector(product_page, config['description']) || ''
    end

    # Pull URL of product image
    def extract_product_image(product_page)
      selector = config['image']
      return nil unless selector

      node = product_page.at(selector)
      src = node&.[]('src')
      return nil unless src

      absolutize_url(product_page.uri.to_s, src)
    rescue URI::Error => e
      LoggerManager.log_error('Failed to extract product image', e, log_context('extract_product_image'))
      nil
    end

    # Extract category name
    def extract_product_category(product_page)
      text_from_selector(product_page, config['category']) || 'General'
    end

    # Extract extra product info table as hash
    def extract_product_info(product_page)
      selector = config['product_info']
      return {} unless selector

      table = product_page.at(selector)
      return {} unless table

      table.search('tr').each_with_object({}) do |row, acc|
        header = row.at('th')&.text&.strip
        value = row.at('td')&.text&.strip
        next unless header

        key = header.downcase.gsub(/\s+/, '_').to_sym
        acc[key] = value
      end
    rescue StandardError => e
      LoggerManager.log_error('Failed to extract product info', e, log_context('extract_product_info'))
      {}
    end

    # Check URL availability
    def check_url_response(url)
      return false if url.to_s.strip.empty?

      response = @agent.head(url)
      response.code.to_i.between?(200, 399)
    rescue Mechanize::ResponseCodeError => e
      if e.response_code == '405'
        !!fetch_page(url, @agent)
      else
        LoggerManager.log_error("URL is not accessible: #{url}", e, log_context('check_url_response'))
        false
      end
    rescue StandardError => e
      LoggerManager.log_error("Failed to check URL: #{url}", e, log_context('check_url_response'))
      false
    end

    private

    def parse_product_links(links)
      return if links.empty?

      queue = Queue.new
      links.each { |link| queue << link }

      worker_count = [@thread_pool_size, links.size].min
      threads = Array.new(worker_count) do
        Thread.new do
          thread_agent = build_agent
          loop do
            link = queue.pop(true)
            parse_product_page(link, thread_agent)
          rescue ThreadError
            break
          rescue StandardError => e
            LoggerManager.log_error('Worker crashed while parsing product page', e,
                                    log_context('parse_product_links'))
          end
        end
      end

      threads.each(&:join)
    end

    def fetch_page(url, agent_instance = nil)
      return nil if url.to_s.strip.empty?

      mech = agent_instance || @agent || build_agent
      mech.get(url)
    rescue Mechanize::ResponseCodeError => e
      LoggerManager.log_error("Failed to fetch page: #{url}", e, log_context('fetch_page'))
      nil
    rescue SocketError, Net::ReadTimeout, Net::OpenTimeout => e
      LoggerManager.log_error("Network error while fetching page: #{url}", e, log_context('fetch_page'))
      nil
    rescue StandardError => e
      LoggerManager.log_error("Unexpected error while fetching page: #{url}", e, log_context('fetch_page'))
      nil
    end

    def extract_product_availability_text(product_page)
      text_from_selector(product_page, config['availability'])
    end

    def parse_availability_flag?(text)
      return false unless text

      normalized = text.downcase
      normalized.include?('in stock') || normalized.include?('available')
    end

    def extract_next_page_link(page)
      selector = config['next_page_link']
      return nil unless selector

      node = page.at(selector)
      href = node&.[]('href')
      return nil unless href

      absolutize_url(page.uri.to_s, href)
    rescue URI::Error => e
      LoggerManager.log_error('Failed to extract next page link', e, log_context('extract_next_page_link'))
      nil
    end

    def build_agent
      agent_config = config['agent'] || {}
      Mechanize.new.tap do |mech|
        mech.user_agent_alias = agent_config['user_agent_alias'] || FALLBACK_USER_AGENT
        mech.read_timeout = agent_config['read_timeout'].to_i.positive? ? agent_config['read_timeout'].to_i : DEFAULT_TIMEOUT
        mech.open_timeout = agent_config['open_timeout'].to_i.positive? ? agent_config['open_timeout'].to_i : DEFAULT_TIMEOUT
        mech.keep_alive = agent_config.fetch('keep_alive', true)
        mech.max_history = 1
      end
    rescue StandardError => e
      LoggerManager.log_error('Failed to build Mechanize agent', e, log_context('build_agent'))
      Mechanize.new
    end

    def resolve_media_root
      app_conf = AppConfigLoader.conf || {}
      media_dir = app_conf['media_dir'] || 'media'
      root_dir = app_conf['root_dir'] || Dir.pwd
      File.expand_path(media_dir, root_dir)
    end

    def ensure_directory(path)
      FileUtils.mkdir_p(path)
    end

    def text_from_selector(page, selector)
      return nil unless selector && page

      node = page.at(selector)
      return nil unless node

      normalize_whitespace(node.text)
    end

    def normalize_whitespace(text)
      text.to_s.gsub(/\s+/, ' ').strip
    end

    def save_product_image(image_url, category, agent_instance)
      return '' if image_url.to_s.strip.empty?

      safe_category = sanitize_segment(category || 'uncategorized')
      category_dir = File.join(@media_root, safe_category)
      ensure_directory(category_dir)

      ext = File.extname(URI.parse(image_url).path)
      ext = '.jpg' if ext.empty?

      filename = "#{sanitize_segment(File.basename(image_url, '.*'))}-#{Digest::SHA1.hexdigest(image_url)}#{ext}"
      path = File.join(category_dir, filename)

      return relative_media_path(path) if File.exist?(path)

      mech = agent_instance || @agent || build_agent
      mech.get(image_url).save(path)

      LoggerManager.log_processed_file(log_context('save_product_image'), 'SUCCESS', "Saved image to #{path}")
      relative_media_path(path)
    rescue StandardError => e
      LoggerManager.log_error("Failed to save product image: #{image_url}", e, log_context('save_product_image'))
      ''
    end

    def relative_media_path(path)
      root_dir = AppConfigLoader.conf&.fetch('root_dir', nil)
      return path unless root_dir

      Pathname.new(path).relative_path_from(Pathname.new(root_dir)).to_s
    rescue StandardError
      path
    end

    def sanitize_segment(text)
      sanitized = text.to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '')
      sanitized.empty? ? 'item' : sanitized
    end

    def absolutize_url(base_url, href)
      return href if href =~ URI::DEFAULT_PARSER.make_regexp

      URI.join(base_url, href).to_s
    end

    def determine_thread_pool_size
      threads = config['threads'] || config.dig('agent', 'threads')
      threads = threads.to_i
      threads.positive? ? threads : DEFAULT_THREAD_POOL
    end

    def validate_config!
      raise ArgumentError, 'Config must be a hash' unless config.is_a?(Hash)
      raise ArgumentError, 'Config must include start_page' if config.fetch('start_page', '').to_s.strip.empty?
    end

    def log_context(method_name)
      "#{self.class}##{method_name}"
    end
  end
end
