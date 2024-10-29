# app/controllers/recipes_controller.rb
require 'openai'
require 'httpclient'

class RecipesController < ApplicationController
  def new
    @recipe = Recipe.new
  end

  def create
    if params[:ingredients].present?
      # 食材をOpenAIで翻訳
      translated_ingredients = params[:ingredients].map { |ingredient| translate_ingredient(ingredient) }
      query = translated_ingredients.reject(&:blank?).join(",")
      nutrients = params[:nutrients].is_a?(Array) ? params[:nutrients] : [params[:nutrients]]
      # OpenAIで献立を生成
      @meal_plan = generate_menu_with_openai(translated_ingredients, nutrients)

      # Edamam APIで栄養情報を取得
      @nutrition_info = translated_ingredients.each_with_object({}) do |ingredient, info|
        info[ingredient] = fetch_nutrition(ingredient)
      end
    else
      render :new
      return  # アクション終了
    end

    render :show
  end

  private

  # OpenAIを使って献立を生成するメソッド
  def generate_menu_with_openai(ingredients, nutrients)
    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

    # OpenAIに送る指示（プロンプト）
    prompt = <<~TEXT
      以下の食材と栄養素を考慮して、**完全に日本語で**バランスの良い1日分の朝・昼・晩の献立を提案してください。
      食材: #{ingredients.join(", ")}
      栄養素: #{nutrients.join(", ")}

      各食事に簡単な調理手順も含めてください。
    TEXT

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 500
      }
    )

    response["choices"].first["message"]["content"]
  end

  # Edamam APIから栄養情報を取得するメソッド
  def fetch_nutrition(ingredient)
    client = HTTPClient.new
    app_id = ENV['EDAMAM_APP_ID']
    app_key = ENV['EDAMAM_APP_KEY']

    endpoint = "https://api.edamam.com/api/nutrition-data"
    response = client.get(endpoint, {
      query: {
        "app_id" => app_id,
        "app_key" => app_key,
        "ingr" => ingredient
      }
    })

    JSON.parse(response.body)
  end

  # 食材の翻訳メソッド
  def translate_ingredient(ingredient)
    client = OpenAI::Client.new
    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [ { role: "user", content: "Translate the following ingredient to English: #{ingredient}" } ]
      }
    )
    response["choices"].first["message"]["content"].strip
  end
end
