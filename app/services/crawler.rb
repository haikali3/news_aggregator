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

  # Force Harian Metro publisher language to BM
  if publisher.name == "Harian Metro"
    publisher.update(language: "BM")
  else
    publisher.update(language: "EN") if publisher.language.blank?
  end

    response = HTTParty.get(@feed_url)
    if response.success?
      Rails.logger.info "Feed fetched successfully for #{@feed_url}"
      Rails.logger.debug "Feed response body: #{response.body[0..500]}"
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
    items = doc.xpath("//item")
    Rails.logger.info "Found #{items.size} items in rss feed"

    items.each_with_index do |item, index|
      title = item.at("title")&.text
      link = item.at("link")&.text
      published_date = item.at("pubDate")&.text

      # Handle media:thumbnail with namespace-aware lookup
      media_thumbnail = item.at_xpath("media:thumbnail", "media" => "http://search.yahoo.com/mrss/")&.[]("url")
      main_image = media_thumbnail || item.at_xpath("media:content", "media" => "http://search.yahoo.com/mrss/")&.[]("url")

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
    if html_content.blank?
      Rails.logger.warn "No HTML content to extract img from"
      return nil
    end

    doc = Nokogiri::HTML(html_content)
    img = doc.at("img")
    image_src = img&.[]("src")
    Rails.logger.info "Extracted image source: #{image_src}"
    image_src
  end

  def categorize(title, publisher)
    keyword_mapping = {
      "World" => /\b(world|international|global|overseas|abroad)\b/i,
      "Food" => /\b(food|recipe|cuisine|restaurant|eat|drink|cafe|dining)\b/i,
      "Sports" => /\b(sports|football|soccer|basketball|tennis|cricket|athletics|olympics)\b/i,
      "Technology" => /\b(tech|technology|software|hardware|ai|robotics|gadgets|innovation)\b/i,
      "Entertainment" => /\b(entertainment|movie|music|tv|celebrity|hollywood|bollywood)\b/i,
      "Politics" => /\b(politics|election|government|policy|minister|parliament)\b/i
    }

    # default categories
    publisher_defaults = {
      "Eat Drink KL" => "Food",
      "SAYS" => "News",
      "Harian Metro" => "News"
    }

    # Check the publisher has a predefined category
    return publisher_defaults[publisher] if publisher_defaults.key?(publisher)

    normalized_title = title.downcase

    # match title against keyword mappings
    keyword_mapping.each do |category, regex|
      return category if normalized_title.match?(regex)
    end

    # no match is found
    "News"
  end
end
