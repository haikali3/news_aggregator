require "nokogiri"
require "httparty"

class Crawler
  def initialize(feed_url, publisher_name)
    @feed_url = feed_url
    @publisher_name = publisher_name
  end

  def fetch_articles
    publisher = Publisher.find_or_create_by(name: @publisher_name)
    publisher.update(language: "EN") if publisher.language.blank?

    response = HTTParty.get(@feed_url)
    doc = Nokogiri::XML(response.body)

    # so atom feed can be parsed with simple xpaths
    doc.remove_namespaces!

    if doc.at("rss")
      Rails.logger.info "Processing RSS feed for #{@feed_url}"
      process_rss(doc)
    elsif doc.at("feed")
      Rails.logger.info "Processing Atom feed for #{@feed_url}"
      # Rails.logger.info "Feed Content: #{doc.to_xml}"
      process_atom(doc)
    else
      Rails.logger.error "Unknown feed format for #{@feed_url}"
    end

    if Article.where(publisher: publisher).empty?
      Rails.logger.error "No articles found for #{@publisher_name} (#{@feed_url})"
    end
  end

  private

  # rss feeds
  def process_rss(doc)
    doc.xpath("//item").each do |item|
      process_article(
        title: item.at("title")&.text,
        link: item.at("link")&.text,
        published_date: item.at("pubDate")&.text,
        main_image: item.at("media|thumbnail")&.[]("url") || item.at("media|content")&.[]("url")
      )
    end
  end

  # atom feeds
  def process_atom(doc)
    doc.xpath("//entry").each do |entry|
      # Handle relative links
      link = entry.at("link[rel='alternate']")&.[]("href")
      link = URI.join(@feed_url, link).to_s if link && !link.start_with?("http")

      # Parse the content HTML for images and additional info
      content_html = entry.at("content")&.text
      main_image = extract_first_image(content_html)

      # Extract required fields
      title = entry.at("title")&.text
      published_date = entry.at("published")&.text || entry.at("updated")&.text

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
    return if title.blank? || link.blank? || published_date.blank?

    publisher = Publisher.find_or_create_by(name: @publisher_name)
    category = categorize(title, publisher.name)

    Article.create_with(
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

    Rails.logger.info "Article processed: #{title} (#{link})"
  end

  def extract_first_image(html_content)
    return nil if html_content.blank?

    doc = Nokogiri::HTML(html_content)
    img = doc.at("img")
    img&.[]("src")
  end

  def categorize(title, publisher)
    if publisher == "Eat Drink KL"
      "Food"
    elsif title.match(/world/i)
      "World"
    else
      "News"
    end
  end
end
