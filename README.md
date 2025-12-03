# 🕷️ Web Crawler

A Ruby-based web scraper for collecting structured book data from [Books to Scrape](http://books.toscrape.com/) — a sandbox site designed for practicing web scraping techniques.

## How It Works

The crawler begins at the homepage and works through the catalogue page by page. On each listing page, it collects links to individual book detail pages, then hands those links off to a pool of worker threads for parallel processing. Each thread navigates to a book's detail page and extracts the title, description, price, stock availability, category, and a table of additional product information such as UPC, tax, and review count. The cover image is downloaded and saved into a category-based folder structure under the `media/` directory.

Once a listing page is fully processed, the crawler looks for a "next" pagination link. If one exists, it moves on and repeats the process; otherwise, parsing is complete. All collected items are then exported to the configured output formats — CSV, JSON, and individual YAML files grouped by category — and optionally persisted to a SQLite or MongoDB database. Finally, the output folder is bundled into a timestamped ZIP archive for convenient storage or transfer.
