class RecipeService
  include MealTimeConverter

  def initialize(user)
    @user = user
  end

  def create_meal_plans(selected_dates, main_nutrients, side_nutrients = nil, category = nil)
    created_plans = []

    selected_dates.each do |date, meal_times|
      meal_times.each do |meal_time|
        # 献立を生成
        meal_plan = generate_meal_plan(main_nutrients, side_nutrients, meal_time, category)

        # 生成した献立を保存
        if meal_plan.present?
          plan = save_meal_plan(meal_plan, date, meal_time)
          created_plans << plan if plan.present?
        end
      end
    end

    created_plans
  end

  private

  def generate_meal_plan(main_nutrients, side_nutrients, meal_time, category = nil)
    # 時間帯とカテゴリーを取得
    meal_period, meal_category = get_meal_period_and_category(meal_time, category)

    # 献立候補を取得
    available_meals = get_available_meals(meal_period, meal_category)
    return get_default_meal_plan if available_meals.empty?

    # 栄養素に基づいてフィルタリング
    filtered_meals = filter_by_nutrients(available_meals, main_nutrients)
    filtered_meals = available_meals if filtered_meals.empty?

    # 最近使った献立を避ける
    recent_meals = get_recent_meals(5)
    history_filtered_meals = filter_by_history(filtered_meals, recent_meals)

    # 候補がなくなった場合は履歴フィルターを無視
    filtered_meals = history_filtered_meals.empty? ? filtered_meals : history_filtered_meals

    # 献立を選択
    selected_meal = select_meal(filtered_meals, recent_meals)
    return get_default_meal_plan if selected_meal.nil?

    # 栄養情報を取得
    nutrients_info = generate_nutrition_info(selected_meal, main_nutrients, side_nutrients)

    # 最終的な献立情報を構築
    {
      main: selected_meal[:main],
      side: selected_meal[:side],
      cuisine_type: selected_meal[:cuisine_type],
      nutrients: nutrients_info[:nutrients],
      ingredients: nutrients_info[:ingredients],
      difficulty: "3"
    }
  end

  def get_meal_period_and_category(meal_time, category)
    # 時間帯を設定
    meal_period = case meal_time.to_s.downcase
    when "morning" then :morning
    when "afternoon" then :afternoon
    when "evening" then :evening
    else :afternoon
    end

    # カテゴリーを設定（指定がなければランダム）
    meal_category = if category && !category.empty?
                      category.to_sym
    else
                      [ :japanese, :western, :chinese ].sample
    end

    [ meal_period, meal_category ]
  end

  def get_available_meals(meal_period, meal_category)
    # 献立データベースから取得
    meals = MealVariations::MEAL_VARIATIONS.dig(meal_period, meal_category)

    # 献立が見つからない場合はフォールバック
    if meals.nil?
      meals = MealVariations::MEAL_VARIATIONS.dig(meal_period, :japanese)

      # それでも見つからない場合は昼食の和食を試す
      if meals.nil?
        meals = MealVariations::MEAL_VARIATIONS.dig(:afternoon, :japanese)
      end
    end

    # nil の場合は空配列を返す
    meals || []
  end

  def get_recent_meals(limit = 5)
    return [] unless @user

    # 最近の献立を取得
    @user.calendar_plans
         .where(created_at: 2.weeks.ago..Time.current)
         .order(created_at: :desc)
         .limit(limit)
         .map do |plan|
           begin
             meal = JSON.parse(plan.meal_plan, symbolize_names: true)
             { main: meal[:main], side: meal[:side] }
           rescue
             nil
           end
         end.compact
  end

  def filter_by_nutrients(meals, required_nutrients)
    return meals if required_nutrients.blank?

    # 栄養素名を標準化
    normalized_required = normalize_nutrients(required_nutrients)

    # 栄養素条件に合致する献立をフィルタリング
    meals.select do |meal|
      normalized_required.all? do |required|
        meal[:nutrients].any? do |provided|
          provided == required ||
          (required == "carbs" && provided == "carbohydrates") ||
          (required == "carbohydrates" && provided == "carbs")
        end
      end
    end
  end

  def normalize_nutrients(nutrients)
    nutrients.map do |n|
      case n
      when "タンパク質" then "protein"
      when "脂質" then "fat"
      when "炭水化物" then "carbs"
      when "ビタミン" then "vitamins"
      when "ミネラル" then "minerals"
      else n.downcase
      end
    end
  end

  def filter_by_history(meals, recent_meals)
    return meals if recent_meals.empty?

    # 最近使った献立の組み合わせ
    recent_combos = recent_meals.map { |m| "#{m[:main]}_#{m[:side]}" }

    # 最近使った献立と重複しないものを選択
    meals.reject do |meal|
      recent_combos.include?("#{meal[:main]}_#{meal[:side]}")
    end
  end

  def select_meal(filtered_meals, recent_meals)
    # 80%の確率でランダムな組み合わせを作る
    if rand < 0.8 && filtered_meals.size >= 2
      random_meal = create_random_combination(filtered_meals, recent_meals)
      return random_meal if random_meal
    end

    # 通常の選択（既存の組み合わせから）
    filtered_meals.sample
  end

  def create_random_combination(meals, recent_meals)
    # 主菜と副菜を別々に抽出
    main_dishes = meals.map { |m| { name: m[:main], cuisine_type: m[:cuisine_type] } }.uniq { |d| d[:name] }
    side_dishes = meals.map { |m| { name: m[:side], cuisine_type: m[:cuisine_type] } }.uniq { |d| d[:name] }

    # 最近使った組み合わせ
    recent_combos = recent_meals.map { |m| "#{m[:main]}_#{m[:side]}" }

    # 最大10回試行
    10.times do
      main = main_dishes.sample
      side = side_dishes.sample
      combo = "#{main[:name]}_#{side[:name]}"

      # 過去に使った組み合わせでなければ採用
      unless recent_combos.include?(combo)
        return {
          main: main[:name],
          side: side[:name],
          cuisine_type: main[:cuisine_type],
          nutrients: []
        }
      end
    end

    nil # 10回試行しても良い組み合わせが見つからなかった
  end

  def get_default_meal_plan
    {
      main: "白身魚のムニエル",
      side: "グリーンサラダ",
      cuisine_type: "洋食",
      nutrients: [ "protein", "fat", "vitamins" ],
      difficulty: "2"
    }
  end

  def generate_nutrition_info(meal, main_nutrients, side_nutrients)
    begin
      openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

      prompt = <<~PROMPT
        【料理】
        主菜: #{meal[:main]}
        副菜: #{meal[:side]}

        【主菜の重点栄養素】
        #{main_nutrients.join('、')}

        【副菜の重点栄養素】
        #{side_nutrients.present? ? side_nutrients.join('、') : "主菜を補完する栄養素"}

        この料理の栄養情報と材料リストを以下の形式のJSONで提供してください：

        {
          "nutrients": {
            "protein": "g",
            "fat": "g",
            "carbohydrates": "g",
            "vitamins": ["含まれる主要なビタミン"],
            "minerals": ["含まれる主要なミネラル"]
          },
          "ingredients": ["材料と分量のリスト"]
        }

        重要: ユーザーが選択した栄養素（#{main_nutrients.join('、')}）が豊富に含まれる食材を必ず含めてください。
      PROMPT

      response = openai_client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [
            { role: "system", content: "あなたは栄養士です。料理の栄養情報を正確に提供します。" },
            { role: "user", content: prompt }
          ],
          temperature: 0.7,
          max_tokens: 400,
          response_format: { type: "json_object" }
        }
      )

      result = response.dig("choices", 0, "message", "content")
      JSON.parse(result, symbolize_names: true)
    rescue => e
      # エラー時のフォールバック
      {
        nutrients: {
          protein: "15g",
          fat: "10g",
          carbohydrates: "20g",
          vitamins: [ "ビタミンA", "ビタミンC" ],
          minerals: [ "カルシウム", "鉄分" ]
        },
        ingredients: generate_ingredients_for_nutrients(meal, main_nutrients)
      }
    end
  end

  def generate_ingredients_for_nutrients(meal, nutrients)
    ingredients = [ "#{meal[:main]}の材料", "#{meal[:side]}の材料" ]

    # 各栄養素に対応する代表的な食材を追加
    nutrients.each do |nutrient|
      case nutrient
      when "タンパク質", "protein"
        ingredients << "鶏肉100g" << "豆腐150g" << "卵2個"
      when "脂質", "fat"
        ingredients << "サラダ油大さじ1" << "ごま油小さじ2" << "バター10g"
      when "炭水化物", "carbs", "carbohydrates"
        ingredients << "ごはん150g" << "じゃがいも100g" << "パン1枚"
      when "ビタミン", "vitamins"
        ingredients << "ほうれん草80g" << "にんじん50g" << "ブロッコリー60g"
      when "ミネラル", "minerals"
        ingredients << "ひじき20g" << "小松菜80g" << "わかめ15g"
      end
    end

    ingredients
  end

  def save_meal_plan(meal_plan, date, meal_time)
    return nil unless valid_meal_plan?(meal_plan)

    begin
      # 時間帯を数値に変換
      numeric_meal_time = case meal_time.to_s.downcase
      when "morning" then 0
      when "afternoon" then 1
      when "evening" then 2
      else 0
      end

      date_obj = Date.parse(date)

      # トランザクション開始
      ActiveRecord::Base.transaction do
        # 既存の献立を削除
        existing_plan = CalendarPlan.find_by(
          user: @user,
          date: date_obj,
          meal_time: numeric_meal_time
        )
        existing_plan&.destroy

        # カテゴリーを設定
        category = get_category_from_cuisine_type(meal_plan[:cuisine_type])

        # レシピ作成
        recipe = Recipe.create!(
          name: "#{meal_plan[:main]}、#{meal_plan[:side]}",
          description: meal_plan.to_json,
          category: category
        )

        # 献立作成
        CalendarPlan.create!(
          user: @user,
          recipe: recipe,
          date: date_obj,
          meal_time: numeric_meal_time,
          meal_plan: meal_plan.to_json
        )
      end
    rescue => e
      nil
    end
  end

  def valid_meal_plan?(meal_plan)
    meal_plan.is_a?(Hash) && meal_plan[:main].present? && meal_plan[:side].present?
  end

  def get_category_from_cuisine_type(cuisine_type)
    if cuisine_type.is_a?(String)
      case cuisine_type
      when "和食" then "japanese"
      when "中華" then "chinese"
      when "洋食" then "western"
      else "japanese"
      end
    else
      "japanese"
    end
  end
end
