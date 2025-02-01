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

      【重要：栄養価の計算手順】
      1. 主食の栄養価（特に注意が必要）：
         ・ごはん100g：タンパク質2.5g、脂質0.3g、炭水化物37g
         ・食パン1枚（60g）：タンパク質5.8g、脂質2.2g、炭水化物32g
         ・うどん100g（茹）：タンパク質2.6g、脂質0.6g、炭水化物25g

      2. おかずの食材（100gあたり）：
         肉・魚・卵類：
         ・鶏肉100g：タンパク質24g、脂質2g、炭水化物0g
         ・卵1個（50g）：タンパク質6g、脂質5g、炭水化物0.3g
      #{'   '}
         野菜類：
         ・ほうれん草100g：タンパク質2g、脂質0.2g、炭水化物2.4g
         ・キャベツ100g：タンパク質1.3g、脂質0.2g、炭水化物4.4g

      3. 調味料：
         ・サラダ油大さじ1（12g）：脂質12g
         ・みりん大さじ1：炭水化物7g

      【計算時の注意点】
      - 主食を含む場合は、その炭水化物量を必ず計算に入れてください
      - 調味料の量も具体的に記載し、栄養価に加えてください
      - 材料はすべて重量を明記してください

      以下の形式のJSONで出力してください：
      {
        "main": "主菜名",
        "side": "副菜名",
        "cuisine_type": "和食/洋食/中華",
        "nutrients": {
          "protein": "各食材の合計値（単位gを付ける）",
          "fat": "各食材と調理油の合計値（単位gを付ける）",
          "carbohydrates": "各食材の合計値（単位gを付ける）",
          "vitamins": ["含まれるビタミン"],
          "minerals": ["含まれるミネラル"]
        },
        "ingredients": ["材料と具体的な量を記載（例：「豆腐150g」）"],
        "difficulty": "2"
      }

      ※ 必ず各食材の量から正確に栄養価を計算してください
      ※ 調味料や油の量も具体的に記載し、栄養価に含めてください
    PROMPT
  end

def generate_meal_plan(nutrients, meal_time)
  max_attempts = 5  # 最大5回まで試行します
  attempts = 0

  while attempts < max_attempts
    # 過去2週間の献立を取得
    recent_meals = CalendarPlan.where(
      user: @user,
      created_at: 2.weeks.ago..Time.current
    ).map { |plan| JSON.parse(plan.meal_plan) }

    # 料理のジャンル選択
    cuisine_types = [ "洋食", "和食", "中華" ]
    last_cuisine = recent_meals.first&.dig("cuisine_type")
    available_cuisines = cuisine_types - [ last_cuisine ].compact
    selected_cuisine = available_cuisines.sample || cuisine_types.sample

    # OpenAI APIで献立を生成
    openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    system_message = "あなたは料理のプロフェッショナルとして、栄養バランスがよく、調理時間の短い献立を提案してください。"
    user_message = create_prompt(nutrients, meal_time)

    begin
      response = openai_client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [
            { role: "system", content: system_message },
            { role: "user", content: user_message }
          ],
          temperature: 1.0,
          max_tokens: 500
        }
      )

      result = response.dig("choices", 0, "message", "content")
      Rails.logger.info("API Response: #{result}")

      if result.present?
        parsed_result = JSON.parse(result, symbolize_names: true)
        if valid_meal_plan?(parsed_result) && !duplicate_meal?(parsed_result, recent_meals)
          return parsed_result  # 有効な献立が見つかったら返す
        end
        # 重複または無効な場合は再試行
        Rails.logger.info("献立が重複または無効なため再生成します（#{attempts + 1}回目）")
      end
    rescue => e
      Rails.logger.error("エラーが発生しました: #{e.message}")
    end

    attempts += 1  # 試行回数を増やす
  end

  nil  # 最大試行回数を超えた場合はnilを返す
end
  def valid_meal_plan?(plan)
    # まず基本的な構造チェック
    return false unless plan.is_a?(Hash)

    begin
      # 必須フィールドの存在と型チェック
      return false unless plan[:main].is_a?(String) && !plan[:main].empty?
      return false unless plan[:side].is_a?(String) && !plan[:side].empty?
      return false unless plan[:cuisine_type].is_a?(String) && !plan[:cuisine_type].empty?
      return false unless plan[:ingredients].is_a?(Array) && !plan[:ingredients].empty?
      return false unless plan[:difficulty].is_a?(String)

      # 栄養情報のチェック
      nutrients = plan[:nutrients]
      return false unless nutrients.is_a?(Hash)

      # 数値の抽出と検証
      protein = nutrients[:protein].to_s.match(/(\d+)g/)&.[](1).to_i
      fat = nutrients[:fat].to_s.match(/(\d+)g/)&.[](1).to_i
      carbs = nutrients[:carbohydrates].to_s.match(/(\d+)g/)&.[](1).to_i

      # 栄養価が現実的な範囲内かチェック
      return false if protein == 0 || protein > 100
      return false if fat == 0 || fat > 100
      return false if carbs == 0 || carbs > 100

      # ビタミンとミネラルの存在チェック
      return false unless nutrients[:vitamins].is_a?(Array) && !nutrients[:vitamins].empty?
      return false unless nutrients[:minerals].is_a?(Array) && !nutrients[:minerals].empty?

      true
    rescue => e
      Rails.logger.error("Meal plan validation error: #{e.message}")
      false
    end
  end

  def save_meal_plan(meal_plan, date, meal_time)
    ActiveRecord::Base.transaction do
      # 同じ日時の献立を確認して削除
      existing_plan = CalendarPlan.find_by(
        user: @user,
        date: date,
        meal_time: meal_time
      )
      existing_plan&.destroy

      # レシピの作成と保存
      recipe = Recipe.create!(
        name: "#{meal_plan[:main]}、#{meal_plan[:side]}",
        description: meal_plan.to_json
      )

      # 献立の保存
      CalendarPlan.create!(
        user: @user,
        recipe: recipe,
        date: Date.parse(date),
        meal_time: meal_time,
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

  def duplicate_meal?(new_meal, recent_meals)
    recent_meals.each do |meal|
      begin
        # JSON文字列の場合はパースする
        meal = meal.is_a?(String) ? JSON.parse(meal) : meal

        # 主菜と副菜の両方が一致する場合のみ重複とみなす
        if same_dish?(new_meal[:main], meal["main"]) &&
           same_dish?(new_meal[:side], meal["side"])
          Rails.logger.info("完全に同じ献立が見つかりました")
          return true
        end

        # 食材の重複チェック
        new_ingredients = filter_main_ingredients(new_meal[:ingredients])
        existing_ingredients = filter_main_ingredients(meal["ingredients"])
        common_ingredients = new_ingredients & existing_ingredients

        # ログ出力を詳細化
        Rails.logger.info("献立比較:")
        Rails.logger.info("  新規献立: #{new_meal[:main]}/#{new_meal[:side]}")
        Rails.logger.info("  既存献立: #{meal["main"]}/#{meal["side"]}")
        Rails.logger.info("  共通食材: #{common_ingredients.join(', ')}")

        # 共通の主要食材が4つ以上ある場合のみ重複とみなす
        if common_ingredients.size >= 4
          Rails.logger.info("共通の主要食材が多すぎます（#{common_ingredients.size}個）")
          return true
        end
      rescue => e
        Rails.logger.error("重複チェックでエラー: #{e.message}")
      end
    end

    false  # 重複する献立が見つからなかった
  end

  def filter_main_ingredients(ingredients)
    return [] unless ingredients.is_a?(Array)

    # 食材の正規化と調味料の除外
    ingredients.map { |i| normalize_ingredient(i) }
              .reject { |i| seasoning?(i) }
              .reject(&:blank?)
  end

  def same_dish?(dish1, dish2)
    # 料理名の正規化と比較をより厳密に
    name1 = normalize_dish_name(dish1)
    name2 = normalize_dish_name(dish2)

    # 完全一致の場合のみtrueを返す
    if name1 == name2
      Rails.logger.info("料理名が一致: #{dish1} == #{dish2}")
      true
    else
      false
    end
  end

  def normalize_dish_name(name)
    # 料理名の正規化をより厳密に
    name.to_s
        .downcase
        .gsub(/[\s　・,、.．]/, "")  # 空白記号と区切り文字を削除
        .gsub(/[ぁ-ん]/, &:upcase)  # ひらがなをカタカナに統一
        .gsub(/[ァ-ン]/, &:upcase)  # カタカナを大文字に統一
  end

  # 調味料リスト
  SEASONINGS = %w[
    しょうゆ 醤油 塩 砂糖 みりん 酒 油 ごま油
    さとう 味噌 みそ だし ソース 酢
  ].freeze

  def normalize_ingredient(ingredient)
    # 食材名から量を除去して正規化
    ingredient.to_s
             .gsub(/\d+[g|個|枚|ml|cc|カップ|本|匹].*/, "")
             .strip
  end

  def seasoning?(ingredient)
    # 調味料かどうかのチェックを強化
    SEASONINGS.any? { |s| ingredient.include?(s) } ||
    ingredient.match?(/小さじ|大さじ|少々|適量|調味料/)
  end
end
