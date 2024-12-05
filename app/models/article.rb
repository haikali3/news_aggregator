class Article < ApplicationRecord
  belongs_to :publisher
  validates :title, :link, :published_date, presence: true

  # filtering articles by language, bm or en
  scope :by_language, ->(lang) {
    joins(:publisher).where(publishers: { language: lang })
  }
end
