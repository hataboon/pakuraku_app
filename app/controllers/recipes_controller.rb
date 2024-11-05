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
        Rails.logger.info("createアクションないの@nutrition_info: #{@nutrition_info.inspect}")
      else
        flash.now[:alert] = "該当するレシピが見つかりませんでした。別の食材をお試しください。"
        render :new
        return
      end
    else
      flash.now[:alert] = "食材を入力してください。"
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
    else
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
def analyze_nutrition_with_openai(ingredients)
  client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

  # プロンプトの修正部分を保持
  prompt = <<~PROMPT
    以下の食材について、それぞれの五大栄養素（炭水化物、脂質、タンパク質、ビタミン、ミネラル）をできる限り数値またはパーセンテージで示してください。ビタミンやミネラルは種類ごとにmgまたはµgの単位で示してください。
    食材名: <食材名>
  - 炭水化物: <数値><単位>
  - 脂質: <数値><単位>
  - タンパク質: <数値><単位>
  - ビタミン: ビタミンC <数値><単位>, ビタミンA <数値><単位>（ビタミンがない場合は「なし」と記載）
  - ミネラル: カリウム <数値><単位>, カルシウム <数値><単位>（ミネラルがない場合は「なし」と記載）
    食材リスト: #{ingredients.join(', ')}
PROMPT

  response = client.chat(
    parameters: {
      model: "gpt-3.5-turbo",
      messages: [ { role: "user", content: prompt } ]
    }
  )
  Rails.logger.info("OpenAI APIのレスポンス: #{response.inspect}")

  # OpenAIからの応答をテキストとして取得
  nutrition_text = response["choices"].first["message"]["content"].strip
  Rails.logger.info("OpenAIからの栄養素データ: #{nutrition_text}")

  # 解析した栄養情報の初期化
  nutrition_info = {}
  current_ingredient = nil

  begin
    # 1行ずつOpenAIのレスポンスを解析する
    nutrition_text.lines.each do |line|
      Rails.logger.info("解析中の行: #{line.strip}")
      line.strip!

      # 食材名を検出するための正規表現を使用して条件を明確化
      if line.match?(/^食材名: /)
        current_ingredient = line.split(/：|:/, 2).last.strip  # 食材名を取得
        nutrition_info[current_ingredient] = {}
        Rails.logger.info("新しい食材を追加: #{current_ingredient}")
      elsif current_ingredient && line.start_with?("- ")
        # 栄養情報の行をパースし、栄養素の内容がある場合に追加する
        key, value = line.sub("- ", "").split(/：|:/, 2)
        if key && value
          nutrition_info[current_ingredient][key.strip] = value.strip
          Rails.logger.info("栄養情報を追加 - 食材: #{current_ingredient}, 栄養素: #{key.strip}, 値: #{value.strip}")
        else
          Rails.logger.warn("パースできなかった行: #{line.strip}")
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error("栄養情報の解析に失敗しました: #{e.message}")
    Rails.logger.error("解析に失敗したテキスト: #{nutrition_text}")
    Rails.logger.error("解析途中のデータ: #{nutrition_info.inspect}")
    nutrition_info = {} # エラー発生時は空の構造にする
  end

  # デバッグ用ログで解析結果を出力
  Rails.logger.info("解析後の栄養情報: #{nutrition_info.inspect}")
  nutrition_info
end
end
