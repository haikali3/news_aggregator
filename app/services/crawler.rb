require "nokogiri"
require "httparty"

class Crawler
  def initialize(feed_url, publisher_name)
    @feed_url = feed_url
    @publisher_name = publisher_name
  end

  def fetch_articles
    Rails.logger.info "Starting fetch for feed: #{@feed_url}, publisher: #{@publisher_name}"

    publisher = Publisher.find_or_create_by(name: @publisher_name)
    Rails.logger.info "Publisher: #{publisher.name} (ID: #{publisher.id})"
    publisher.update(language: "EN") if publisher.language.blank?

    response = HTTParty.get(@feed_url)
    if resnpose.success?
      Rails.logger.info "Feed fetched successfully for #{@feed_url}"
      Rails.logger.debug "Feed resnpose body: #{response.body[0..500]}"
    else
      Rails.logger.error "Failed to fetch feed for #{@feed_url}. Response code: #{response.code}"
      return
    end

    doc = Nokogiri::XML(response.body)
    # atom feed can be parsed with simple xpaths
    doc.remove_namespaces!
    Rails.logger.info "Feed parsed, root element: #{doc.root.name}"

    # feed type
    if doc.at("rss")
      Rails.logger.info "Processing RSS feed for #{@feed_url}"
      process_rss(doc)
    elsif doc.at("feed")
      Rails.logger.info "Processing Atom feed for #{@feed_url}"
      process_atom(doc)
    else
      Rails.logger.error "Unknown feed format for #{@feed_url}"
    end

    if Article.where(publisher: publisher).empty?
      Rails.logger.error "No articles found for #{@publisher_name} (#{@feed_url})"
    else
      Rails.logger.info "Articles fetched for #{@publisher_name} (#{@feed_url})"
    end
  end

  private

  # rss feeds
  def process_rss(doc)
    items doc.xpath("//item")
    Rails.logger.info "Found #{items.size} items in rss feed"

    items.each_with_index do |item, index|
      title = item.at("title")&.text
      link = item.at("link")&.text
      published_date = item.at("pubDate")&.text
      main_image = item.at("media|thumbnail")&.[]("url") || item.at("media|content")&.[]("url")

      Rails.logger.info "Processing RSS item ##{index + 1}: title=#{title}, link=#{link}, published_date=#{published_date}, main_image=#{main_image}"

      process_article(
        title: title,
        link: link,
        published_date: published_date,
        main_image: main_image
      )
    end
  end

  # atom feeds
  def process_atom(doc)
    entries = doc.xpath("//entry")
    Rails.logger.info "Found #{entries.size} entries in atom feed"

    entries.each_with_index do |entry, index|
      title = entry.at("title")&.text
      link = entry.at("link[rel='alternate']")&.[]("href")
      link = URI.join(@feed_url, link).to_s if link && !link.start_with?("http")
      published_date = entry.at("published")&.text || entry.at("updated")&.text
      content_html = entry.at("content")&.text
      main_image = extract_first_image(content_html)

      Rails.logger.info "Processing Atom entry ##{index + 1}: title=#{title}, link=#{link}, published_date=#{published_date}, main_image=#{main_image}"

      # Process the article
      process_article(
        title: title,
        link: link,
        published_date: published_date,
        main_image: main_image
      )
    end
  end

  def process_article(title:, link:, published_date:, main_image:)
    if title.blank? || link.blank? || published_date.blank?
      Rails.logger.warn "Skipping article due to missing data: title=#{title}, link=#{link}, published_date=#{published_date}"
      return
    end

    Rails.logger.info "Attempting to process article: #{title} (#{link})"

    publisher = Publisher.find_or_create_by(name: @publisher_name)
    category = categorize(title, publisher.name)

    article = Article.create_with(
      main_image: main_image || "placeholder.jpg",
      published_date: begin
                        DateTime.parse(published_date)
                      rescue StandardError
                        nil
                      end
    ).find_or_create_by(link: link) do |article|
      article.title = title
      article.publisher = publisher
      article.categories = category
    end

    if article.persisted?
      Rails.logger.info "Article processed successfully: #{article.title} (ID: #{article.id})"
    else
      Rails.logger.error "Failed to create article: #{article.errors.full_messages.join(', ')}"
    end
  end

  def extract_first_image(html_content)
    if html_content
      Rails.logger.warn "No HTML content to extract img from"
      return nil
    end

    doc = Nokogiri::HTML(html_content)
    img = doc.at("img")
    img&.[]("src")
    Rails.logger.info "Extracted image source: #{image_src}"
    image_src
  end

  def categorize(title, publisher)
    # Lowercase the title once to simplify multiple keyword checks
    normalized_title = title.downcase

    # Publishers and logic
    case publisher
    when "Eat Drink KL"
      # All Eat Drink KL articles go to 'Food' by default
      "Food"
    when "SAYS", "Harian Metro"
      # Check if the title contains keywords that imply international scope
      if normalized_title.match(/\b(world|international|global|overseas|abroad)\b/)
        "World"
      else
        # Otherwise, treat it as local news
        "News"
      end
    else
      # For any other publisher, check the title similarly
      if normalized_title.match(/\b(world|international|global|overseas|abroad)\b/)
        "World"
      else
        # Default category if no keywords are found
        "News"
      end
    end
  end
end
