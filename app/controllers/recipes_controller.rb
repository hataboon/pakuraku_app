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

  # 献立データを解析して表示用のデータを作成するメソッド
  def parse_meal_plans(calendar_plans)
    calendar_plans.map do |plan|
      begin
        # 献立データをJSONとして解析
        meal_plan = JSON.parse(plan.meal_plan, symbolize_names: true)
        nutrients = meal_plan[:nutrients]

        # 栄養データをグラフ表示用に変換
        chart_data = {
          protein: nutrients[:protein].to_s.scan(/\d+/).first&.to_i || 0,
          carbohydrates: nutrients[:carbohydrates].to_s.scan(/\d+/).first&.to_i || 0,
          fat: nutrients[:fat].to_s.scan(/\d+/).first&.to_i || 0,
          vitamins: calculate_nutrient_score(nutrients[:vitamins]),
          minerals: calculate_nutrient_score(nutrients[:minerals])
        }

        # 元のデータにグラフ用データを追加
        meal_plan.merge(chart_data: chart_data)
      rescue JSON::ParserError => e
        # JSONの解析に失敗した場合はログを残す
        Rails.logger.error "JSON parse error: #{e.message}"
        nil
      end
    end.compact  # nilを除外して返す
  end

  # 栄養素のスコアを計算するメソッド
  def calculate_nutrient_score(nutrient_data)
    return 0 if nutrient_data.blank?

    case nutrient_data
    when Array
      # 配列の場合は要素数からスコアを計算
      [ nutrient_data.size * 33, 100 ].min
    when String
      # カンマ区切りの文字列の場合は分割してカウント
      [ nutrient_data.split(",").size * 33, 100 ].min
    else
      0
    end
  end
end
