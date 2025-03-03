# app/services/recipe_service.rb
class RecipeService
  include MealTimeConverter
  include MealVariations

  def initialize(user)
    @user = user
  end

  def create_meal_plans(selected_dates, main_nutrients, side_nutrients = nil, category = nil)
    Rails.logger.info("Category in create_meal_plans: #{category}")
    if main_nutrients.empty?
      raise ValidationError.new("主菜の栄養素を一つ以上選択してください")
    end

    plans = []
    selected_dates.each do |date, meal_times|
      meal_times.each do |meal_time|
        Rails.logger.info("Calling generate_meal_plan with: #{main_nutrients}, #{side_nutrients}, #{meal_time}, #{category}")

        meal_plan = generate_meal_plan(main_nutrients, side_nutrients, meal_time, category)
        if meal_plan
          calendar_plan = save_meal_plan(meal_plan, date, meal_time)
          plans << calendar_plan if calendar_plan
        end
      end
    end
    plans
  end

  private

  def generate_meal_plan(main_nutrients, side_nutrients, meal_time, category = nil)
    # 時間帯を文字列から記号に変換
    meal_period = case meal_time.to_s.downcase
    when "morning" then :morning
    when "afternoon" then :afternoon
    when "evening" then :evening
    else :afternoon  # デフォルトは昼食
    end

    # カテゴリーを文字列から記号に変換
    meal_category = if category && !category.empty?
                      category.to_sym
    else
                      # カテゴリーが指定されていない場合はランダムに選択
                      [ :japanese, :western, :chinese ].sample
    end

    # 選択された時間帯とカテゴリーの献立リストを取得
    available_meals = MealVariations::MEAL_VARIATIONS.dig(meal_period, meal_category)

    # available_meals が nil の場合の対応
    if available_meals.nil?
      Rails.logger.error "No meals available for period: #{meal_period}, category: #{meal_category}"
      # デフォルトのカテゴリーを使う
      meal_category = :japanese
      available_meals = MealVariations::MEAL_VARIATIONS.dig(meal_period, meal_category)

      # それでも nil なら別の時間帯を試す
      if available_meals.nil?
        Rails.logger.error "Falling back to default meal period and category"
        meal_period = :afternoon
        available_meals = MealVariations::MEAL_VARIATIONS.dig(meal_period, :japanese)
      end
    end

    # それでも nil なら空の配列を使用
    available_meals ||= []

    # 栄養素によるフィルタリング
    Rails.logger.debug "Filtering meals by nutrients: #{main_nutrients}"
    filtered_meals = filter_by_nutrients(available_meals, main_nutrients)
    Rails.logger.debug "After nutrient filtering, #{filtered_meals.count} meals remain"

    # 栄養素に合致する献立がない場合
    if filtered_meals.empty?
      Rails.logger.warn "No meals match the selected nutrients. Using all available meals for this time and category."
      filtered_meals = available_meals
    end

    # 最近使った献立を除外
    recent_meals = get_recent_meals(5)
    filtered_meals = filter_by_history(filtered_meals, recent_meals)
    Rails.logger.debug "After history filtering, #{filtered_meals.count} meals remain"

    # フィルタリング後に候補がなくなった場合は履歴フィルタを無視
    if filtered_meals.empty?
      Rails.logger.warn "All matching meals were recently used. Ignoring history filter."
      filtered_meals = filter_by_nutrients(available_meals, main_nutrients)
      filtered_meals = available_meals if filtered_meals.empty?
    end

    # ランダム性を導入するか決定（80%の確率でランダムな組み合わせを作る）
    use_random_combination = rand < 0.8

    if use_random_combination && filtered_meals.size >= 2
      Rails.logger.info "Creating a random combination of main and side dishes"

      # すべての主菜と副菜を抽出
      main_dishes = filtered_meals.map { |meal| { name: meal[:main], cuisine_type: meal[:cuisine_type] } }.uniq { |dish| dish[:name] }
      side_dishes = filtered_meals.map { |meal| { name: meal[:side], cuisine_type: meal[:cuisine_type] } }.uniq { |dish| dish[:name] }

      # 栄養バランスを考慮して選ぶ（最大10回試行）
      max_attempts = 10
      attempts = 0

      while attempts < max_attempts
        # ランダムに選ぶ
        random_main = main_dishes.sample
        random_side = side_dishes.sample

        combo = "#{random_main[:name]}_#{random_side[:name]}"

        # 過去に使った組み合わせではないかチェック
        if recent_meals.none? { |m| "#{m[:main]}_#{m[:side]}" == combo }
          # OK、この組み合わせを使う
          selected_meal = {
            main: random_main[:name],
            side: random_side[:name],
            cuisine_type: random_main[:cuisine_type],  # 主菜のタイプを使用
            nutrients: [] # 空の配列を一時的に設定、実際はgenerate_nutrition_infoで生成される
          }
          break
        end

        attempts += 1
      end

      # 全ての試行が失敗した場合は、通常の選択方法にフォールバック
      if attempts >= max_attempts
        Rails.logger.warn "Could not create a unique random combination, using predefined meal"
        selected_meal = filtered_meals.sample
      end
    else
      # 通常の選択（定義済みの組み合わせ）
      selected_meal = filtered_meals.sample
    end

    # 選択された献立がない場合はデフォルトを返す
    if selected_meal.nil?
      Rails.logger.warn "No suitable meal found, creating a default meal plan"
      return {
        main: "白身魚のムニエル",
        side: "グリーンサラダ",
        cuisine_type: "洋食",
        nutrients: [ "protein", "fat", "vitamins" ],
        difficulty: "2"
      }
    end

    # 栄養素情報を取得・生成
    nutrients_info = generate_nutrition_info(selected_meal, main_nutrients, side_nutrients)

    # 完全な献立情報を構築
    {
      main: selected_meal[:main],
      side: selected_meal[:side],
      cuisine_type: selected_meal[:cuisine_type],
      nutrients: nutrients_info[:nutrients],
      ingredients: nutrients_info[:ingredients],
      difficulty: "3"
    }
  end

  # 栄養素条件に基づいて献立をフィルタリング
  def filter_by_nutrients(meals, required_nutrients)
    # 文字列の栄養素を統一形式に変換
    normalized_required = required_nutrients.map do |n|
      case n
      when "タンパク質" then "protein"
      when "脂質" then "fat"
      when "炭水化物" then "carbs"
      when "ビタミン" then "vitamins"
      when "ミネラル" then "minerals"
      else n.downcase
      end
    end

    # 栄養素条件に合致する献立をフィルタリング
    meals.select do |meal|
      # すべての要求栄養素が含まれているかチェック
      normalized_required.all? do |required|
        meal[:nutrients].any? do |provided|
          # 直接一致またはcarbs/carbohydratesの同義語対応
          provided == required ||
          (required == "carbs" && provided == "carbohydrates") ||
          (required == "carbohydrates" && provided == "carbs")
        end
      end
    end
  end

  # 過去の献立を避けるフィルタリング
  def filter_by_history(meals, recent_meals)
    recent_meal_combos = recent_meals.map { |m| "#{m[:main]}_#{m[:side]}" }
    meals.reject do |meal|
      recent_meal_combos.include?("#{meal[:main]}_#{meal[:side]}")
    end
  end

  # 最近の献立を取得
  def get_recent_meals(limit = 5)
    CalendarPlan.where(
      user: @user,
      created_at: 2.weeks.ago..Time.current
    ).order(created_at: :desc).limit(limit).map do |plan|
      begin
        meal = JSON.parse(plan.meal_plan, symbolize_names: true)
        {
          main: meal[:main],
          side: meal[:side]
        }
      rescue
        nil
      end
    end.compact
  end

  # 選択された献立の栄養情報を生成
  def generate_nutrition_info(meal, main_nutrients, side_nutrients)
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
          { role: "system", content: "あなたは栄養士です。料理の栄養情報を正確に提供します。選択された栄養素が豊富に含まれる食材を必ず含めてください。" },
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
    Rails.logger.error("栄養情報生成エラー: #{e.message}")
    # エラーの場合はデフォルト値を返す
    {
      nutrients: {
        protein: "15g",
        fat: "10g",
        carbohydrates: "20g",
        vitamins: [ "ビタミンA", "ビタミンC" ],
        minerals: [ "カルシウム", "鉄分" ]
      },
      ingredients: generate_ingredients_for_nutrients(meal, main_nutrients) # 栄養素に基づいた材料を生成
    }
  end

  # 栄養素に基づいた食材リストを生成するフォールバックメソッド
  def generate_ingredients_for_nutrients(meal, nutrients)
    ingredients = [ "#{meal[:main]}の材料", "#{meal[:side]}の材料" ]

    # 各栄養素に対応する代表的な食材を追加
    nutrients.each do |nutrient|
      case nutrient
      when "タンパク質"
        ingredients << "鶏肉100g" << "豆腐150g" << "卵2個"
      when "脂質"
        ingredients << "サラダ油大さじ1" << "ごま油小さじ2" << "バター10g"
      when "炭水化物"
        ingredients << "ごはん150g" << "じゃがいも100g" << "パン1枚"
      when "ビタミン"
        ingredients << "ほうれん草80g" << "にんじん50g" << "ブロッコリー60g"
      when "ミネラル"
        ingredients << "ひじき20g" << "小松菜80g" << "わかめ15g"
      end
    end

    ingredients
  end

  def save_meal_plan(meal_plan, date, meal_time)
    Rails.logger.debug "Saving meal plan with: date=#{date}, meal_time=#{meal_time}"

    # meal_plan が nil または無効な場合は早期リターン
    return nil unless meal_plan.is_a?(Hash) && meal_plan[:main].present? && meal_plan[:side].present?

    numeric_meal_time = case meal_time.to_s.downcase
    when "morning" then 0
    when "afternoon" then 1
    when "evening" then 2
    else 0
    end

    Rails.logger.debug "Converting meal_time '#{meal_time}' to numeric_meal_time: #{numeric_meal_time}"

    ActiveRecord::Base.transaction do
      # 同じ日時の献立を確認して削除
      existing_plan = CalendarPlan.find_by(
        user: @user,
        date: date,
        meal_time: numeric_meal_time
      )
      existing_plan&.destroy

      # カテゴリーを判定（cuisine_typeから適切なカテゴリーに変換）
      # cuisine_type が文字列かどうか確認
      cuisine_type = meal_plan[:cuisine_type]
      category = if cuisine_type.is_a?(String)
        case cuisine_type
        when "和食" then "japanese"
        when "中華" then "chinese"
        when "洋食" then "western"
        else "japanese" # デフォルト
        end
      else
        "japanese" # デフォルト
      end

      # レシピの作成と保存
      recipe = Recipe.create!(
        name: "#{meal_plan[:main]}、#{meal_plan[:side]}",
        description: meal_plan.to_json,
        category: category
      )

      # 献立の保存
      CalendarPlan.create!(
        user: @user,
        recipe: recipe,
        date: Date.parse(date),
        meal_time: numeric_meal_time,
        meal_plan: meal_plan.to_json
      )

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("保存エラー: #{e.message}")
      raise
    end
  rescue StandardError => e
    Rails.logger.error("予期せぬエラー: #{e.message}")
    nil
  end

  def format_nutrient_requirements(nutrients)
    return "" unless nutrients.present?

    requirements = nutrients.map do |nutrient|
      case nutrient
      when "タンパク質"
        "・タンパク質が豊富な食材を使用（目安：15-25g）"
      when "脂質"
        "・適度な脂質を含む調理法（目安：10-15g）"
      when "炭水化物"
        "・適度な炭水化物を含む食材選択（目安：20-30g）"
      when "ビタミン"
        "・ビタミン類が豊富な野菜を使用"
      when "ミネラル"
        "・ミネラルを含む食材を積極的に使用"
      end
    end

    requirements.join("\n")
  end
end
