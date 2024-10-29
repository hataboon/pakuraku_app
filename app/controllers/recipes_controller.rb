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
      render :new
      return  # アクション終了
    end

    # Edamam APIリクエスト
    begin
      client = HTTPClient.new()
      res = client.get("https://api.edamam.com/api/recipes/v2?type=public&q=#{CGI.escape(query)}&app_id=#{ENV['application_id']}&app_key=#{ENV['application_keys']}")
      recipes = JSON.parse(res.body)["hits"]
    rescue => e
      puts "Edamam APIでエラー発生: #{e.message}"
      render plain: "Edamam APIでエラーが発生しました。"
      return  # エラーが発生した場合はここで終了
    end

    # 1つの献立を生成
    @meal_plan = generate_single_meal_plan_in_japanese(recipes)
    render :show
  end

  private

  # 1つの献立を生成
  def generate_single_meal_plan_in_japanese(recipes)
    client = OpenAI::Client.new
    begin
      # 1つのレシピを使って献立を作成するリクエスト
      recipe = recipes.first["recipe"]
      recipe_label = recipe["label"]
      ingredients = recipe["ingredientLines"].join(", ")

      response = client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [
          { role: "user", content: "Translate the following recipe into Japanese: Recipe name: #{recipe_label}. Ingredients: #{ingredients}" }
        ],
          max_tokens: 150  # トークン数を少し減らして1つの献立だけを生成
        }
      )
      response["choices"].first["message"]["content"]
    rescue Faraday::TooManyRequestsError => e
      puts "OpenAI APIのリクエスト制限エラー: #{e.message}"
      render plain: "OpenAI APIのリクエスト制限に達しました。しばらくしてから再試行してください。"
      nil  # エラー時にreturnでアクション終了
    rescue => e
      puts "OpenAI APIでその他のエラー発生: #{e.message}"
      render plain: "OpenAI APIでエラーが発生しました。"
      nil  # その他のエラー時にreturnでアクション終了
    end
  end

  def translate_ingredient(ingredient)
    client = OpenAI::Client.new
    retries = 0

    begin
      response = client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [ { role: "user", content: "Translate the following ingredient to English: #{ingredient}" } ]
        }
      )
      response["choices"].first["message"]["content"].strip
    rescue Faraday::TooManyRequestsError => e
      # リクエスト制限エラー時のバックオフ処理
      if retries < 3  # 最大3回までリトライ
        retries += 1
        sleep(2 ** retries)  # 2秒、4秒、8秒と待機時間を増加
        retry
      else
        puts "OpenAI APIのリクエスト制限エラー: #{e.message}"
        render plain: "OpenAI APIのリクエスト制限に達しました。しばらくしてから再試行してください。"
        nil  # エラー時にreturnでアクション終了
      end
    rescue => e
      puts "OpenAI APIでその他のエラー発生: #{e.message}"
      render plain: "OpenAI APIでエラーが発生しました。"
      nil  # その他のエラー時にreturnでアクション終了
    end
  end
end
