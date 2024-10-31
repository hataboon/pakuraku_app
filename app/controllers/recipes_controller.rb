# app/controllers/recipes_controller.rb
require "openai"
require "httpclient"

class RecipesController < ApplicationController
  def new
    @recipe = Recipe.new
  end

  def create
    if params[:ingredients].present?
      translated_ingredients = params[:ingredients].map do |ingredient|
        translate_ingredient(ingredient)
      end
      query = translated_ingredients.reject(&:blank?).join(", ")

      # 楽天レシピAPIでレシピ情報を取得
      @meal_plan = fetch_rakuten_recipe_details(query)

      # Edamam APIで栄養素情報を取得
      if @meal_plan && @meal_plan[:ingredients]
        @nutrition_info = @meal_plan[:ingredients].each_with_object({}) do |ingredient, info|
          # 重複しないようにingredientを適切にフォーマットする
          cleaned_ingredient = ingredient.gsub(/(\d+\swhole\s)/, '').strip
          info[ingredient] = fetch_nutrition(cleaned_ingredient)
        end
      end
    else
      render :new
      return
    end

    render :show
  end

  private

  def fetch_recipe_image(ingredient)
    # 仮にEdamam APIが画像URLを返すと仮定して処理
    client = HTTPClient.new
    app_id = ENV["EDAMAM_APP_ID"]
    app_key = ENV["EDAMAM_APP_KEY"]
    
    # レシピ検索APIで食材に関連する画像を取得
    response = client.get("https://api.edamam.com/api/recipes/v2", {
      query: {
        "app_id" => app_id,
        "app_key" => app_key,
        "q" => ingredient,
        "type" => "public"
      }
    })
  
    # レスポンスをパース
    data = JSON.parse(response.body)
    
    # 画像URLを取得（存在しない場合に備え、デフォルトURLも設定）
    image_url = data.dig("hits", 0, "recipe", "image") || "/assets/default_recipe_image.png"
    image_url
  end
 
  def translate_ingredient(ingredient)
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [{ role: "user", content: "Translate the following ingredient to English: #{ingredient}" }]
      }
    )
    translated_ingredient = response["choices"].first["message"]["content"].strip
    Rails.logger.info("Translated ingredient: #{translated_ingredient}")
    translated_ingredient
  end
  

  # **楽天レシピAPIでレシピIDを取得し、レシピの詳細情報を取得するメソッド**（新規追加）
  # app/controllers/recipes_controller.rb

  def fetch_rakuten_recipe_details(query)
    client = HTTPClient.new
    application_id = ENV["RAKUTEN_APP_ID"]
  
    # カテゴリ別ランキングAPIでレシピIDと詳細情報を一度に取得
    category_endpoint = "https://app.rakuten.co.jp/services/api/Recipe/CategoryRanking/20170426"
    category_response = client.get(category_endpoint, {
      query: {
        "applicationId" => application_id,
        "keyword" => query,
        "format" => "json"
      }
    })
  
    category_data = JSON.parse(category_response.body)
  
    # レシピが見つからなければnilを返す
    recipe = category_data.dig("result", 0)
    return unless recipe
  
    # 取得したデータから詳細情報を直接返す
    {
      title: recipe["recipeTitle"],
      url: recipe["recipeUrl"],
      image: recipe["foodImageUrl"],
      ingredients: recipe["recipeMaterial"], # 材料リスト
      steps: recipe["recipeIndication"]
    }
  end
  


  # app/controllers/recipes_controller.rb

  def fetch_nutrition(ingredient)
    client = HTTPClient.new
    app_id = ENV["EDAMAM_APP_ID"]
    app_key = ENV["EDAMAM_APP_KEY"]
    
    endpoint = "https://api.edamam.com/api/nutrition-data"
    response = client.get(endpoint, {
      query: {
        "app_id" => app_id,
        "app_key" => app_key,
        "ingr" => ingredient # 量を除外してリクエスト
      }
    })
    
    data = JSON.parse(response.body)
    Rails.logger.info("Edamam APIの完全なレスポンス: #{data.inspect}")

    if data["totalNutrients"].empty?
       Rails.logger.warn("栄養データが取得できませんでした。食材が正しく認識されなかった可能性があります。")
    end

    data
  end
  


end