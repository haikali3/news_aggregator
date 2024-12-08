# README

- Services (job queues, cache servers, search engines, etc.)
  scrape with sidekiq

- Run cron job
  `bundle exec sidekiq`

- Enqueue the worker (in rails console)
  `rails console`

- Run worker
  `ArticleFetcherWorker.perform_async`

- This line of code creates a new instance of the ArticleFetcherWorker class and calls its perform method.
- The perform method is responsible for fetching articles from various sources and processing them accordingly.
  `ArticleFetcherWorker.new.perform`

## Redis

- start redis server
  `redis-server`

- stop redis server
  `redis-cli shutdown`

## How to clear data in db

- Clear db in rails console

  ```
  # Clear all data
  Article.destroy_all
  Publisher.destroy_all

  # Reset auto-increment IDs
  ActiveRecord::Base.connection.reset_pk_sequence!('articles')
  ActiveRecord::Base.connection.reset_pk_sequence!('publishers')
  ```

TODO:

1. The app should be able to filter the articles by language (English / BM).
2. Your code should be able to easily handle any new addition of publishers.
3. The app should allow one to see a list of the publishers as well (not just a hardcoded list).
