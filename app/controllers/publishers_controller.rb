class PublishersController < ApplicationController
  def index
    @publishers = Publisher.all
    render json: @publishers
  end

  def show
    @publisher = Publisher.find(params[:id])
    render json: @publisher
  end
end
