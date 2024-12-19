class RecipesController < ApplicationController
  include NutritionsHelper
  before_action :authenticate_user!, only: [ :new, :create ]

  def new
    @calendar_plans = CalendarPlan.where(user: current_user).includes(:recipe)
    @nutrients = %w[ミネラル たんぱく質 炭水化物 ビタミン 脂質]
  end

  def create
    selected_dates = params[:selected_dates] || {}
    selected_nutrients = params[:nutrients] || []
    normalized_selected_nutrients = selected_nutrients.map { |n| n.tr("ァ-ン", "ぁ-ん").downcase }
    plans = []

    # 新しい献立の保存前に既存の献立を削除する
    CalendarPlan.where(user: current_user, date: selected_dates.keys).destroy_all

    selected_dates.each do |date, meal_times|
      meal_times.each do |meal_time|
        generated_meal_plan = generate_meal_plan_with_randomness(normalized_selected_nutrients, meal_time)
        meal_plan = generated_meal_plan || create_default_meal_plan
        calendar_plan = save_meal_plan(meal_plan, date, meal_time)
        plans << calendar_plan if calendar_plan
      end
    end

    if plans.present?
      redirect_to recipe_path(id: plans.first.date), notice: "献立を作成しました。"
    else
      redirect_to new_recipe_path, alert: "献立の作成に失敗しました。"
    end
  end

  def show
    @calendar_plans = CalendarPlan.where(user: current_user, date: params[:id])

    if @calendar_plans.blank?
      flash[:alert] = "該当する献立が見つかりませんでした。"
      redirect_to new_recipe_path and return
    end

    @parsed_meal_plans = @calendar_plans.map do |plan|
      begin
        JSON.parse(plan.meal_plan, symbolize_names: true)
      rescue JSON::ParserError => e
        Rails.logger.error("JSON Parse Error: #{e.message}")
        nil
      end
    end.compact

    Rails.logger.debug("Parsed Meal Plans: #{@parsed_meal_plans.inspect}")

    if @parsed_meal_plans.blank?
      flash[:alert] = "献立データが正しく読み込めませんでした。"
      redirect_to new_recipe_path
    end
  end

  def destroy
    @calendar_plan = CalendarPlan.find_by(id: params[:id])

    if @calendar_plan
      @calendar_plan.destroy
      flash[:success] = "献立が削除されました。"
    else
      flash[:error] = "献立が見つかりませんでした。"
    end
    redirect_back fallback_location: recipes_path # 削除後にリダイレクト
  end

  private

  DEFAULT_NUTRIENTS = {
    protein: "0g",
    fat: "0g",
    carbohydrates: "0g",
    vitamins: "データなし",
    mineral: "データなし"
  }.freeze

  NORMALIZED_INGREDIENTS = {
    "ご" => "ご飯",
    "ほうれん" => "ほうれん草",
    "だし" => "だし汁",
    "みそ" => "味噌",
    "ごま" => "ごま油",
    "わかめ" => "乾燥わかめ"
  }.freeze

  def complete_nutrients(nutrients)
    DEFAULT_NUTRIENTS.merge(nutrients || {})
  end

  def normalize_ingredients(ingredients)
    (ingredients || []).map { |ingredient| NORMALIZED_INGREDIENTS[ingredient] || ingredient.strip }.reject(&:empty?).uniq
  end

  def fetch_meal_plan_from_api(selected_nutrients, meal_time)
    prompt = <<~PROMPT
    以下の条件を満たす日本の家庭料理の献立を提案してください:
    - 主食、主菜、副菜を必ず含む
    - 主菜が主食と役割を重複させないこと（例: カレーライスが主食の場合、主菜に唐揚げを含めない）
    - 献立全体のバランスを考慮し、次のようなルールを守ること:
    - 料理は毎回異なるものにすること。
    - 以下の主食・主菜・副菜の候補をランダムに組み合わせる:
      * 主食: ご飯、パン、うどん、焼きそば、おにぎり
      * 主菜: 鯖の味噌煮、肉じゃが、豚の生姜焼き、照り焼きチキン、豆腐ステーキ
      * 副菜: ひじきの煮物、きゅうりの浅漬け、もやしのナムル、ほうれん草のおひたし
    - 栄養バランスを考慮し、以下の栄養素を含むこと: #{selected_nutrients.join('、')}
    - 使用する食材例: #{[ "しょうが", "にんにく", "みそ", "ごま油", "青ねぎ" ].sample(2).join("、")}
    - #{meal_time}用の献立として適切な内容にする
    - 各栄養素の表記は具体的な数値（例: 10g）で表記すること。
    - 使用した食材リストには調味料を除き、主な材料のみを含めてください。
    - 不適切な料理名や曖昧な表現を避け、具体的な料理名を使用してください。
    - 以下のフォーマットで、整ったJSONデータとして出力してください:

    {
      "main": "[主食の名前]",
      "side": "[主菜の名前]",
      "salad": "[副菜の名前]",
      "nutrients": {
        "protein": "[タンパク質の量]",
        "fat": "[脂質の量]",
        "carbohydrates": "[炭水化物の量]",
        "vitamins": "[ビタミンの詳細]",
        "minerals": "[ミネラルの詳細]"
      },
      "ingredients": ["[食材1]", "[食材2]", "..."]
    }
  PROMPT



    Rails.logger.debug("送信するプロンプト: #{prompt}")

      client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
      response = client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [ { role: "user", content: prompt } ],
          temperature: 1.0,
          max_tokens: 600
        }
      )

      Rails.logger.debug("APIレスポンス全文: #{response.inspect}")
      JSON.parse(response["choices"].first["message"]["content"], symbolize_names: true)
    rescue JSON::ParserError => e
      Rails.logger.error("JSON Parse Error: #{e.message}")
      nil
    rescue => e
      Rails.logger.error("OpenAI APIリクエストエラー: #{e.message}")
      nil
    end

    def generate_meal_plan_with_randomness(selected_nutrients, meal_time)
      attempts = 0
      max_attempts = 5

      loop do
        Rails.logger.debug("選択された栄養素: #{selected_nutrients}, 時間帯: #{meal_time}, 試行回数: #{attempts + 1}")
        meal_plan = fetch_meal_plan_from_api(selected_nutrients, meal_time)
        Rails.logger.debug("取得された献立: #{meal_plan.inspect}")

        # バリデーション: 献立が被らない場合のみ採用
        if meal_plan && !meal_plan_already_exists?(meal_plan)
          Rails.logger.debug("新しい献立が生成されました。")
          return meal_plan
        end

        attempts += 1
        break if attempts >= max_attempts
      end

      Rails.logger.error("新しい献立の生成に失敗しました。デフォルト献立を利用します。")
      create_default_meal_plan
    end

  def meal_plan_already_exists?(meal_plan)
    CalendarPlan.where(user: current_user).each do |plan|
      begin
        existing_plan = JSON.parse(plan.meal_plan, symbolize_names: true)
        return true if existing_plan[:main] == meal_plan[:main] &&
                       existing_plan[:side] == meal_plan[:side] &&
                       existing_plan[:salad] == meal_plan[:salad]
      rescue JSON::ParserError => e
        Rails.logger.error("JSON パースエラー: #{e.message}")
        next
      end
    end
    false
  end

  def create_default_meal_plan
    {
      main: "白ご飯",
      side: "焼き魚",
      salad: "おひたし",
      nutrients: {
        protein: "20g",
        fat: "5g",
        carbohydrates: "50g",
        vitamin: "ビタミンA, ビタミンC",
        mineral: "カルシウム, 鉄分"
      },
      ingredients: [ "米", "魚", "ほうれん草", "醤油" ],
      raw_response: nil
    }
  end

  def save_meal_plan(meal_plan, date, meal_time)
    recipe = Recipe.create!(
      name: "#{meal_plan[:main]}, #{meal_plan[:side]}, #{meal_plan[:salad]}",
      description: meal_plan.to_json
    )

    CalendarPlan.create!(
      user: current_user,
      recipe: recipe,
      date: Date.parse(date),
      meal_time: meal_time,
      meal_plan: meal_plan.to_json
    )
  end
end
