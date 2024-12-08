README

1. Services (job queues, cache servers, search engines, etc.)

- Scrape with Sidekiq:
  - Run cron job: `bundle exec sidekiq`
  - Enqueue the worker (in Rails console): `rails console`
  - Run worker: `ArticleFetcherWorker.perform_async`
  - Create a new instance of the ArticleFetcherWorker class and call its perform method: `ArticleFetcherWorker.new.perform`
    - The perform method is responsible for fetching articles from various sources and processing them accordingly.

2. Redis

- Start Redis server: `redis-server`
- Stop Redis server: `redis-cli shutdown`

3. How to clear data in db

- Clear db in Rails console:

  ```
  # Clear all data
  Article.destroy_all
  Publisher.destroy_all

  # Reset auto-increment IDs
  ActiveRecord::Base.connection.reset_sequence!('articles', 'id')
  ActiveRecord::Base.connection.reset_sequence!('publishers', 'id')
  ```

4. Endpoint

- Endpoints:

  - GET /articles
  - GET /articles/:id
  - GET /publishers
  - GET /publishers/:id

- Supported Parameters:
  - For GET /articles: language (optional, e.g., ?language=EN or ?language=BM)
  - For GET /articles/:id: :id (required)
  - For GET /publishers: no additional parameters
  - For GET /publishers/:id: :id (required)
