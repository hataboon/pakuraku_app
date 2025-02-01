# app/controllers/recipes_controller.rb
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

  # パラメータのバリデーション
  if selected_dates.empty?
    redirect_to new_recipe_path, alert: "日付を選択してください" and return
  end

  normalized_nutrients = selected_nutrients.map do |n|
    n.to_s.strip.tr("ァ-ン", "ぁ-ん").downcase
  end.reject(&:blank?)

  recipe_service = RecipeService.new(current_user)

  begin
    calendar_plans = recipe_service.create_meal_plans(selected_dates, normalized_nutrients)

    if calendar_plans.present?
      redirect_to recipe_path(id: calendar_plans.first.date),
                  notice: "献立を作成しました。"
    else
      redirect_to new_recipe_path,
                  alert: "献立の生成に失敗しました。時間をおいて再度お試しください。"
    end
  rescue StandardError => e
    Rails.logger.error("献立作成エラー: #{e.class} - #{e.message}")
    redirect_to new_recipe_path,
                alert: "献立の作成中にエラーが発生しました。時間をおいて再度お試しください。"
  end
end
  def show
    @calendar_plans = CalendarPlan.where(user: current_user, date: params[:id])

    if @calendar_plans.present?
      # シェアテキストを生成
      @share_text = generate_share_text(@calendar_plans.first)
      @share_url = request.base_url + recipe_path(params[:id])
      # 献立データを解析
      @parsed_meal_plans = parse_meal_plans(@calendar_plans)
    end
  end

  private

  # 献立のシェアテキストを生成するメソッド
  def generate_share_text(calendar_plan)
    # 献立データをJSONとして解析
    plan = JSON.parse(calendar_plan.meal_plan)

    # 食事時間の日本語表示を設定
    time_mapping = {
      "morning" => "朝食",
      "afternoon" => "昼食",
      "evening" => "夕食"
    }

    # 食事時間を取得（対応する時間帯がない場合は「食事」を使用）
    meal_time = time_mapping[calendar_plan.meal_time.downcase] || "食事"

    # シェアテキストを構築
    text = "【#{meal_time}の献立】\n"
    text += "主菜：#{plan['main']}\n"
    text += "副菜：#{plan['side']}\n"
    text += "#{plan['soup']}\n" if plan["soup"].present?
    text += "\n#パクラク #献立 #料理"

    # URLエンコードして返す
    ERB::Util.url_encode(text)
  end

  def parse_meal_plans(calendar_plans)
    nutrition_service = NutritionCalculationService.new  # デフォルト値を使用

    # 1食あたりの推奨量を計算（1日の推奨量の1/3）
    daily_requirements = nutrition_service.calculate_daily_requirements
    per_meal_requirements = {
      protein: daily_requirements[:protein] / 3,
      fat: daily_requirements[:fat] / 3,
      carbohydrates: daily_requirements[:carbohydrates] / 3
    }

    calendar_plans.map do |plan|
      begin
        meal_plan = JSON.parse(plan.meal_plan, symbolize_names: true)
        nutrients = meal_plan[:nutrients]

        # 数値の抽出（単位"g"を除去）
        protein = nutrients[:protein].to_s.gsub(/[^\d.]/, "").to_f
        fat = nutrients[:fat].to_s.gsub(/[^\d.]/, "").to_f
        carbs = nutrients[:carbohydrates].to_s.gsub(/[^\d.]/, "").to_f

        # ビタミンとミネラルのスコア計算
        vitamins_score = calculate_vitamins_score(nutrients[:vitamins])
        minerals_score = calculate_minerals_score(nutrients[:minerals])

        # パーセンテージの計算（1食あたりの推奨量に対する割合）
        chart_data = {
          values: {
            protein: protein,
            carbohydrates: carbs,
            fat: fat
          },
          percentages: {
            protein: ((protein / per_meal_requirements[:protein]) * 100).round(1),
            carbohydrates: ((carbs / per_meal_requirements[:carbohydrates]) * 100).round(1),
            fat: ((fat / per_meal_requirements[:fat]) * 100).round(1),
            vitamins: vitamins_score,
            minerals: minerals_score
          }
        }

        meal_plan.merge(chart_data: chart_data)
      rescue => e
        Rails.logger.error "データ処理エラー: #{e.message}"
        nil
      end
    end.compact
  end

  def calculate_vitamins_score(vitamins)
    return 0 unless vitamins.is_a?(Array)

    weights = {
      "ビタミンA" => 25,
      "ビタミンD" => 20,
      "ビタミンB1" => 15,
      "ビタミンB2" => 15,
      "ビタミンC" => 25
    }

    total_score = 0
    vitamins.each do |vitamin|
      weight = weights.find { |k, _| vitamin.include?(k) }&.last || 10
      total_score += weight
    end

    [ total_score, 100 ].min
  end

  def calculate_minerals_score(minerals)
    return 0 unless minerals.is_a?(Array)

    weights = {
      "鉄" => 30,
      "カルシウム" => 30,
      "マグネシウム" => 20,
      "亜鉛" => 20
    }

    total_score = 0
    minerals.each do |mineral|
      weight = weights.find { |k, _| mineral.include?(k) }&.last || 10
      total_score += weight
    end

    [ total_score, 100 ].min
  end
end
