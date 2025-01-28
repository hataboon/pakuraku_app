# app/services/recipe_service.rb
class RecipeService
  include MealTimeConverter

  def initialize(user)
    @user = user
  end

  def create_meal_plans(selected_dates, nutrients)
    plans = []
    selected_dates.each do |date, meal_times|
      meal_times.each do |meal_time|
        meal_plan = generate_meal_plan(nutrients, meal_time)
        if meal_plan
          calendar_plan = save_meal_plan(meal_plan, date, meal_time)
          plans << calendar_plan if calendar_plan
        end
      end
    end
    plans
  end

  private


  def create_prompt(nutrients, meal_time)
    <<~PROMPT
      #{meal_time_to_japanese(meal_time)}の献立を提案してください。

      条件：
      1. 栄養素：#{nutrients.join('、')}を意識すること
      2. 調理時間：15分以内
      3. 構成：主菜1品、副菜1品
      4. 一般的な家庭で作れる料理

      以下の形式のJSONで出力してください：
      {
        "main": "主菜名",
        "side": "副菜名",
        "cuisine_type": "和食",
        "nutrients": {
          "protein": "15",
          "fat": "10",
          "carbohydrates": "20",
          "vitamins": ["A", "B1"],
          "minerals": ["鉄", "カルシウム"]
        },
        "cooking_time": "10",
        "ingredients": ["材料1", "材料2"],
        "difficulty": "2"
      }
    PROMPT
  end

  def generate_meal_plan(nutrients, meal_time)
    # 過去2週間の献立を取得
    recent_meals = CalendarPlan.where(
      user: @user,
      created_at: 2.weeks.ago..Time.current
    ).map { |plan| JSON.parse(plan.meal_plan) }

    # 最近使用した料理を抽出
    used_dishes = {
      main: recent_meals.map { |m| m["main"] }.compact.uniq,
      side: recent_meals.map { |m| m["side"] }.compact.uniq,
      ingredients: recent_meals.flat_map { |m| m["ingredients"] }.compact.uniq
    }

    # 料理のジャンル選択（前回と違うものを選ぶ）
    cuisine_types = [ "洋食", "和食", "中華" ]
    last_cuisine = recent_meals.first&.dig("cuisine_type")
    available_cuisines = cuisine_types - [ last_cuisine ].compact
    selected_cuisine = available_cuisines.sample || cuisine_types.sample

    openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    system_message = "あなたは料理のプロフェッショナルとして、栄養バランスがよく、調理時間の短い献立を提案してください。"

    user_message = <<~PROMPT
      【条件】
      - 料理ジャンル：#{selected_cuisine}
      - 時間帯：#{meal_time_to_japanese(meal_time)}
      - 必要な栄養素：#{nutrients.join('、')}
      - 調理時間：15分以内
      - 主菜1品と副菜1品で構成

      【避けるべき組み合わせ】
      - 以下の主菜は使用しない：#{used_dishes[:main].join('、')}
      - 以下の副菜は使用しない：#{used_dishes[:side].join('、')}
      - 可能な限り以下の食材は避ける：#{used_dishes[:ingredients].join('、')}

      以下の形式のJSONで出力してください：
      {
        "main": "主菜名（新しいメニュー）",
        "side": "副菜名（新しいメニュー）",
        "cuisine_type": "#{selected_cuisine}",
        "nutrients": {
          "protein": "15",
          "fat": "10",
          "carbohydrates": "20",
          "vitamins": ["A", "B1"],
          "minerals": ["鉄", "カルシウム"]
        },
        "cooking_time": "10",
        "ingredients": ["材料1", "材料2"],
        "difficulty": "2"
      }
    PROMPT

    begin
      response = openai_client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [
            { role: "system", content: system_message },
            { role: "user", content: user_message }
          ],
          temperature: 1.0,  # より多様な回答を得るために温度を上げる
          max_tokens: 500
        }
      )

      result = response.dig("choices", 0, "message", "content")
      Rails.logger.info("API Response: #{result}")

      if result.present?
        begin
          parsed_result = JSON.parse(result, symbolize_names: true)
          if valid_meal_plan?(parsed_result) && !duplicate_meal?(parsed_result, recent_meals)
            return parsed_result
          end
          Rails.logger.error("Invalid meal plan or duplicate: #{parsed_result}")
        rescue JSON::ParserError => e
          Rails.logger.error("JSON parse error: #{e.message}")
          Rails.logger.error("Raw response: #{result}")
        end
      end

      nil
    rescue OpenAI::Error => e
      Rails.logger.error("OpenAI API Error: #{e.message}")
      nil
    end
  end

  def valid_meal_plan?(plan)
    # 必須フィールドから cooking_methods を削除
    required_fields = {
      main: String,
      side: String,
      cuisine_type: String,
      nutrients: Hash,
      cooking_time: String,
      ingredients: Array,
      difficulty: String
    }

    required_fields.each do |field, type|
      unless plan[field].present? && plan[field].is_a?(type)
        Rails.logger.warn "#{field}が不正です: #{plan[field]}"
        return false
      end
    end

    # 料理のジャンルの妥当性チェック
    valid_cuisine_types = [ "和食", "洋食", "中華", "アジア料理", "その他" ]
    unless valid_cuisine_types.any? { |cuisine| plan[:cuisine_type].include?(cuisine) }
      Rails.logger.warn "料理のジャンルが不正です: #{plan[:cuisine_type]}"
      return false
    end

    # 調理時間の妥当性チェック
    unless plan[:cooking_time].to_i.between?(1, 15)
      Rails.logger.warn "調理時間が範囲外です: #{plan[:cooking_time]}"
      return false
    end

    # 栄養情報の妥当性チェック
    nutrients = plan[:nutrients]
    unless nutrients.is_a?(Hash) &&
           nutrients[:protein].present? &&
           nutrients[:fat].present? &&
           nutrients[:carbohydrates].present?
      Rails.logger.warn "栄養情報が不正です: #{nutrients}"
      return false
    end

    true
  end

  def save_meal_plan(meal_plan, date, meal_time)
    # 同じ日の同じ時間帯の献立が既に存在するかチェック
    existing_plan = CalendarPlan.find_by(
      user: @user,
      date: date,
      meal_time: meal_time
    )

    # 既存の献立がある場合は削除
    existing_plan&.destroy

    ActiveRecord::Base.transaction do
      recipe_name = "#{meal_plan[:main]}、#{meal_plan[:side]}"

      recipe = Recipe.create!(
        name: recipe_name,
        description: meal_plan.to_json
      )

      CalendarPlan.create!(
        user: @user,
        recipe: recipe,
        date: Date.parse(date),
        meal_time: meal_time,
        meal_plan: meal_plan.to_json
      )
    end
  rescue => e
    Rails.logger.error("保存エラー: #{e.message}")
    nil
  end

  def duplicate_meal?(new_meal, recent_meals)
    recent_meals.any? do |meal|
      meal["main"] == new_meal[:main] ||
      meal["side"] == new_meal[:side] ||
      (meal["ingredients"] & new_meal[:ingredients]).size >= 2
    end
  end
end
