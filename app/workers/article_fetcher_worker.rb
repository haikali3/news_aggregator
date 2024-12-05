class ArticleFetcherWorker
  include Sidekiq::Worker

  def perform
    publishers = {
      "https://says.com/my/rss" => "SAYS",
      "https://www.hmetro.com.my/feed" => "Harian Metro",
      "https://www.eatdrinkkl.com/posts.atom" => "Eat Drink KL"
      # "https://www.freemalaysiatoday.com/feed/" => "Free Malaysia Today"
    }

    publishers.each do |url, name|
      begin
        Crawler.new(url, name).fetch_articles
        Rails.logger.info "Successfully fetched articles for #{name} (#{url})"
      rescue StandardError => e
        Rails.logger.error "Failed to fetch articles for #{name} (#{url}): #{e.message}"
      end
    end
  end
end
