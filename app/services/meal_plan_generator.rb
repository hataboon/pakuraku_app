# app/services/meal_plan_generator.rb
class MealPlanGenerator
  def initialize(user)
    @user = user
  end

  def generate(nutrients, meal_time)
    # 過去の献立を取得して重複を避ける
    recent_meals = fetch_recent_meals

    # 最大5回まで献立生成を試みる
    attempts = 0
    max_attempts = 5

    loop do
      # OpenAI APIを使用して献立を生成
      meal_plan = fetch_meal_plan_from_api(nutrients, meal_time, recent_meals)
      return meal_plan if meal_plan && !meal_plan_already_exists?(meal_plan)

      attempts += 1
      break if attempts >= max_attempts
    end

    nil
  end

  private

  def fetch_recent_meals
    CalendarPlan.where(
      user: @user,
      created_at: 7.days.ago..Time.current
    ).pluck(:meal_plan)
  end

  def fetch_meal_plan_from_api(selected_nutrients, meal_time)
    # 過去の献立から食材を抽出
    recent_plans = CalendarPlan.where(
      user: current_user,
      created_at: 7.days.ago..Time.current
    )

    # 最近使用した食材と料理を抽出
    used_items = []
    used_dishes = []
    recent_plans.each do |plan|
      begin
        meal = JSON.parse(plan.meal_plan)
        used_items.concat(meal["ingredients"]) if meal["ingredients"]
        used_dishes << meal["main"] if meal["main"]
        used_dishes << meal["side"] if meal["side"]
      rescue JSON::ParserError => e
        Rails.logger.error "JSON解析エラー: #{e.message}"
      end
    end

    # 重複を除去
    used_items.uniq!
    used_dishes.uniq!

    prompt = <<~PROMPT
      以下の条件で、具体的な和食の#{meal_time_in_japanese(meal_time)}献立を提案してください。

      【基本条件】
      ・一般的な家庭で作れる料理
      ・調理時間は15分以内
      ・電子レンジなども活用可能

      【重要な制約】
      ・以下の最近使用した食材は避けてください：
      #{used_items.join(", ")}

      ・以下の最近提案した料理は避けてください：
      #{used_dishes.join(", ")}

      【栄養条件】
      ・必要な栄養素: #{selected_nutrients.join(", ")}

      【出力形式】
      {
        "main": "主菜の名前（前回と異なる食材を使用）",
        "side": "副菜の名前（前回と異なる食材を使用）",
        "nutrients": {
          "protein": "15",
          "fat": "10",
          "carbohydrates": "20",
          "vitamins": ["ビタミンA", "ビタミンD"],
          "minerals": ["カルシウム", "鉄分"]
        },
        "cooking_time": "15以内の数値",
        "ingredients": ["食材1", "食材2", "食材3"],
        "difficulty": "2"
      }
    PROMPT

    # ... 残りのコードは同じ ...
  end

  def create_prompt(nutrients, meal_time, recent_meals)
    # 最近使用した料理を確認
    used_recipes = recent_meals.flat_map do |meal|
      begin
        meal = JSON.parse(meal)
        [ meal["main"], meal["side"] ]
      rescue
        []
      end
    end.compact.uniq

    prompt = <<~PROMPT
      以下の条件で、新しい和食の朝食献立を提案してください。

      【重要な方針】
      ・独創的で栄養バランスの良い組み合わせを考えてください
      ・最近提案された以下の料理は避けてください：#{used_recipes.join(", ")}
      ・必要な栄養素（#{nutrients.join(", ")}）を意識した献立
      ・朝食として相応しい料理の組み合わせ
      ・15分以内で作れる料理
      ・一般的な家庭で入手できる食材を使用

      【調理の工夫】
      ・電子レンジ、トースター、魚焼きグリルなどを活用可能
      ・下準備を前日にしておくことも可能
      ・時短テクニックを活用可能

      【出力形式】
      {
        "main": "主菜の名前（新しい発想の料理を提案）",
        "side": "副菜の名前（主菜と栄養バランスが取れる料理）",
        "nutrients": {
          "protein": "15",
          "fat": "10",
          "carbohydrates": "20",
          "vitamins": ["ビタミンA", "ビタミンD"],
          "minerals": ["カルシウム", "鉄分"]
        },
        "cooking_time": "15以内の数値",
        "ingredients": ["食材1", "食材2", "食材3"],
        "difficulty": "2"
      }
    PROMPT

    prompt
  end

  def valid_meal_plan?(plan)
    return false unless plan.is_a?(Hash)

    # 必須項目のチェック
    required_fields = [ :main, :side, :nutrients, :cooking_time, :ingredients ]
    unless required_fields.all? { |field| plan[field].present? }
      Rails.logger.warn "必須フィールドが不足しています: #{required_fields - plan.keys}"
      return false
    end

    # 調理時間のチェック
    if plan[:cooking_time].to_i > 15
      Rails.logger.warn "調理時間が長すぎます: #{plan[:cooking_time]}分"
      return false
    end

    true
  end

  def meal_plan_already_exists?(meal_plan)
    recent_plans = CalendarPlan.where(
      user: @user,
      created_at: 7.days.ago..Time.current
    )

    recent_plans.any? do |plan|
      begin
        existing_plan = JSON.parse(plan.meal_plan, symbolize_names: true)
        existing_plan[:main] == meal_plan[:main] &&
        existing_plan[:side] == meal_plan[:side]
      rescue JSON::ParserError => e
        Rails.logger.error "JSONの解析に失敗: #{e.message}"
        false
      end
    end
  end
end
