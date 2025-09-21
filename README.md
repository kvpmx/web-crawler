# 🕷️ Web Crawler

The project focuses on crawling the website [Books to Scrape](http://books.toscrape.com/),
a sandbox site created specifically for practicing web scraping.
This makes it a safe and legal choice for experimentation.
The purpose of the crawler is to collect structured data about books
and store it in a convenient format for later analysis.

The crawler begins at the homepage and retrieves all the data about available books.
From every catalogue page, links to individual book detail pages are collected.
On each detail page, the crawler extracts comprehensive information
such as the book title, description, price, availability, rating etc. 
Additionally, the URL of the book’s page and the cover image link are gathered.
An optional step is downloading the images themselves into a local folder.

All collected data is stored in a CSV file. Each row corresponds to a single book.
This ensures that the dataset is complete and ready for analysis or integration into other tools.
