class Publisher < ApplicationRecord
  has_many :articles, dependent: :destroy
  validates :name, :language, presence: true
end
