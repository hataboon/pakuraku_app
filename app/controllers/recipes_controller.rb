# app/controllers/recipes_controller.rb
require "openai"
require "httpclient"

class RecipesController < ApplicationController
  def new
    @recipe = Recipe.new
  end

  def create
    if params[:ingredients].present?
      # 楽天API用に日本語のままキーワードを使用する
      query = params[:ingredients].join(", ")
      @meal_plan = fetch_rakuten_recipe_details(query)
      
      if @meal_plan.present? # ここで @meal_plan の有無を確認
        Rails.logger.info("取得した@meal_planの内容: #{@meal_plan.inspect}")
        
        # 献立から食材リストを抽出
        ingredients = @meal_plan[:ingredients] # ここで献立の食材リストを使用
        # OpenAI APIで五大栄養素を取得
        @nutrition_info = analyze_nutrition_with_openai(ingredients)
      else
        flash[:alert] = "該当するレシピが見つかりませんでした。別の食材をお試しください。"
        render :new
        return
      end
    else
      flash[:alert] = "食材を入力してください。"
      render :new
      return
    end
    
    render :show
  end
  
  private

  # 楽天レシピAPIからレシピ情報を取得するメソッド
  def fetch_rakuten_recipe_details(query)
    client = HTTPClient.new
    application_id = ENV["RAKUTEN_APP_ID"]
  
    # Step 1: 楽天カテゴリ一覧APIを使ってカテゴリを取得
    category_response = client.get("https://app.rakuten.co.jp/services/api/Recipe/CategoryList/20170426", {
      query: {
        "applicationId" => application_id,
        "format" => "json"
      }
    })
  
    category_data = JSON.parse(category_response.body)
    Rails.logger.info("楽天レシピカテゴリAPIのレスポンス: #{category_data.inspect}")
  
    # Step 2: キーワードを含むカテゴリを検索（部分一致を許可）
    matching_category = category_data["result"]["large"].find do |category|
      category["categoryName"].include?(query)
    end
  
    # 中カテゴリや小カテゴリも部分一致で検索
    matching_category ||= category_data["result"]["medium"].find { |category| category["categoryName"].include?(query) }
    matching_category ||= category_data["result"]["small"].find { |category| category["categoryName"].include?(query) }
  
    # 該当するカテゴリが見つからない場合はnilを返す
    unless matching_category
      Rails.logger.info("キーワードに該当するカテゴリが見つかりませんでした")
      flash[:alert] = "該当するカテゴリが見つかりませんでした。異なるキーワードをお試しください。"
      return nil
    end
  
    # 親カテゴリIDと結合してカテゴリIDを作成
    category_id = if matching_category["parentCategoryId"]
                    "#{matching_category["parentCategoryId"]}-#{matching_category["categoryId"]}"
                  else
                    matching_category["categoryId"]
                  end
  
    # Step 3: 該当カテゴリIDでレシピを取得
    recipe_response = client.get("https://app.rakuten.co.jp/services/api/Recipe/CategoryRanking/20170426", {
      query: {
        "applicationId" => application_id,
        "categoryId" => category_id,
        "format" => "json"
      }
    })
  
    recipe_data = JSON.parse(recipe_response.body)
    Rails.logger.info("楽天レシピカテゴリ別ランキングAPIのレスポンス: #{recipe_data.inspect}")
  
    # レシピが存在するかを確認
    if recipe_data["result"].present?
      # ランダムでレシピを取得
      matching_recipe = recipe_data["result"].sample
      Rails.logger.info("取得したレシピ: #{matching_recipe.inspect}")
    else
      Rails.logger.info("カテゴリに該当するレシピが存在しませんでした")
      flash[:alert] = "該当するカテゴリにレシピが見つかりませんでした。"
      return nil
    end
  
    return unless matching_recipe
  
    # レシピ詳細を返す
    {
      title: matching_recipe["recipeTitle"],
      url: matching_recipe["recipeUrl"],
      image: matching_recipe["foodImageUrl"],
      ingredients: matching_recipe["recipeMaterial"],
      steps: matching_recipe["recipeIndication"]
    }
  end
  
  
  # OpenAIを使用して食材の栄養情報を取得するメソッド
  # OpenAIを使用して食材の栄養情報を取得するメソッド
# OpenAIを使用して食材の栄養情報を取得するメソッド
def analyze_nutrition_with_openai(ingredients)
  client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
  response = client.chat(
    parameters: {
      model: "gpt-3.5-turbo",
      messages: [{ role: "user", content: "次の食材の栄養素について五大栄養素（炭水化物、脂質、タンパク質、ビタミン、ミネラル）の内容を教えてください: #{ingredients.join(', ')}" }]
    }
  )

  # 取得した内容をテキストとして取り出し
  nutrition_text = response["choices"].first["message"]["content"].strip
  Rails.logger.info("OpenAIからの栄養素データ: #{nutrition_text}")

  # 文字列を解析して構造化データに変換する処理
  nutrition_info = {}
  current_ingredient = nil
  nutrition_text.lines.each do |line|
    line.strip!
    # 食材名の行（例: "天然舞茸："）
    if line.match?(/：$/)
      current_ingredient = line.sub(/：$/, '')
      nutrition_info[current_ingredient] = {}
    elsif current_ingredient && line.start_with?("- ")
      # 栄養素情報の行（例: "- 炭水化物：ほとんど含まれていない"）
      key, value = line.sub("- ", "").split("：", 2)
      nutrition_info[current_ingredient][key] = value
    end
  end

  nutrition_info
end
end
