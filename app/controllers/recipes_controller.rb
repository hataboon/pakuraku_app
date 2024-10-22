class RecipesController < ApplicationController
  def new
    @recipe = Recipe.new
  end

  def create
    if params[:ingredients].present?
      # 食材をOpenAIで翻訳
      translated_ingredients = params[:ingredients].map { |ingredient| translate_ingredient(ingredient) }
      query = translated_ingredients.reject(&:blank?).join(",")
    else
      @foods = []
      render :new
      return
    end

    # Edamam APIリクエスト
    client = HTTPClient.new()
    res = client.get("https://api.edamam.com/api/recipes/v2?type=public&q=#{CGI.escape(query)}&app_id=#{ENV['application_id']}&app_key=#{ENV['application_keys']}")
    recipes = JSON.parse(res.body)

    @recipes = recipes["hits"]
    render :show
  end

  private

  def generate_meal_plan(recipes, duration)
    client = OpenAI::Client.new

    response = client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [{ role: 'user', content: "Create a meal plan for #{duration} days using the following recipes: #{recipes}" }],
        max_tokens: 300
      }
    )
    response['choices'].first['message']['content']
  end

  def translate_ingredient(ingredient)
    client = OpenAI::Client.new
    response = client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [{ role: 'user', content: "Translate the following ingredient to English: #{ingredient}" }]
      }
    )
    response['choices'].first['message']['content'].strip
  end
end
