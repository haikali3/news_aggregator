require "nokogiri"
require "httparty"

class Crawler
  def initialize(feed_url, publisher_name)
    @feed_url = feed_url
    @publisher_name = publisher_name
  end

  def fetch_articles
    response = HTTParty.get(@feed_url)
    doc = Nokogiri::XML(response.body)

    doc.xpath("//item").each do |item|
      title = item.at("title").text
      link = item.at("link").text
      published_date = item.at("pubDate").text
      main_image = item.at("media:content")&.[]("url") || "placeholder.jpg"

      publisher = Publisher.find_or_create_by(name: @publisher_name)
      category = categorize(title, publisher.name)

      Article.create_with(main_image: main_image, published_date: published_date)
              .find_or_create_by(link: link) do |article|
        article.title = title
        article.publisher = publisher
        article.categories = category
      end
    end
  end

  private

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
