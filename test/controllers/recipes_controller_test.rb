require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end
end

require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_recipe_url
    assert_response :success
    assert_not_nil assigns(:recipe)
  end
end

require "test_helper"
