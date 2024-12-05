class ArticlesController < ApplicationController
  def index
    language = params[:language]
    @articles = if language
      Article.by_language(language).order(published_date: :desc)
    else
      Article.order(published_date: :desc)
    end

    render json: @articles
  end

  def show
    @article = Article.find(params[:id])
    render json: @article
  end
end
