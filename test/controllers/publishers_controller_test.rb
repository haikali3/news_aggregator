require "test_helper"

class PublishersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @publisher = publishers(:one) # Assuming you have a fixture named 'one' for publishers
  end
  test "should get index" do
    get publishers_url
    assert_response :success
  end

  test "should get show" do
    get publishers_url(@publisher)
    assert_response :success
  end
end
