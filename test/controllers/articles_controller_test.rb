require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @article = articles(:one) # Assuming you have a fixture named 'one' for articles
  end

  test "should get index" do
    get articles_url
    assert_response :success
  end

  test "should get show" do
    get article_url(@article)
    assert_response :success
  end
end
