class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title
      t.string :main_image
      t.datetime :published_date
      t.string :link
      t.references :publisher, null: false, foreign_key: true
      t.string :categories

      t.timestamps
    end
  end
end
