class NutritionsController < ApplicationController
  before_action :authenticate_user!

  def show
    @period = params[:period] || 'week'  # デフォルトは過去7日間
    
    # 期間に基づいて日付範囲を設定
    set_date_range
    
    # 栄養データと推奨値を計算
    @nutrition_data = calculate_nutrition_data(@start_date, @end_date)
    @recommended_values = get_recommended_values
    
    respond_to do |format|
      format.html
      format.json { render json: { data: @nutrition_data, recommended: @recommended_values } }
    end
  end

  private
  
  def set_date_range
    case @period
    when 'today'
      @start_date = Date.today
      @end_date = Date.today
    when 'week'
      @start_date = 6.days.ago.to_date
      @end_date = Date.today
    when 'month'
      @start_date = Date.today.beginning_of_month
      @end_date = Date.today
    when 'last_month'
      @start_date = Date.today.last_month.beginning_of_month
      @end_date = Date.today.last_month.end_of_month
    else
      # カスタム範囲の場合
      @start_date = parse_date(params[:start_date], 1.month.ago.to_date)
      @end_date = parse_date(params[:end_date], Date.today)
    end
  end

  def parse_date(date_param, default)
    date_param.present? ? Date.parse(date_param) : default
  rescue ArgumentError
    default
  end

  def calculate_nutrition_data(start_date, end_date)
    plans = CalendarPlan.where(user: current_user)
                       .where(date: start_date..end_date)

    total_nutrients = {
      protein: 0,
      carbohydrates: 0,
      fat: 0,
      vitamins: 0,
      minerals: 0
    }

    plans.each do |plan|
      begin
        meal_plan = JSON.parse(plan.meal_plan)
        nutrients = meal_plan["nutrients"]

        # 数値の抽出（単位"g"を除去）
        total_nutrients[:protein] += nutrients["protein"].to_s.gsub(/[^\d.]/, "").to_f
        total_nutrients[:carbohydrates] += nutrients["carbohydrates"].to_s.gsub(/[^\d.]/, "").to_f
        total_nutrients[:fat] += nutrients["fat"].to_s.gsub(/[^\d.]/, "").to_f
        total_nutrients[:vitamins] += calculate_nutrient_score(nutrients["vitamins"])
        total_nutrients[:minerals] += calculate_nutrient_score(nutrients["minerals"])
      rescue => e
        Rails.logger.error "栄養データの解析エラー: #{e.message}"
      end
    end

    # 日数で割って平均値を算出
    period_days = (end_date - start_date).to_i + 1
    days = period_days > 0 ? period_days : 1
    
    # 1日あたりの平均値を計算
    {
      values: {
        protein: (total_nutrients[:protein] / days).round(1),
        carbohydrates: (total_nutrients[:carbohydrates] / days).round(1),
        fat: (total_nutrients[:fat] / days).round(1)
      },
      percentages: {
        vitamins: [(total_nutrients[:vitamins] / days).round(1), 100].min,
        minerals: [(total_nutrients[:minerals] / days).round(1), 100].min
      }
    }
  end

  def calculate_nutrient_score(nutrient_str)
    return 0 if nutrient_str.blank?
    count = nutrient_str.split(",").size
    [ count * 33, 100 ].min
  end
  
  # 推奨栄養値を取得するメソッド
  def get_recommended_values
    # ユーザーの性別や年齢から推奨値を計算（仮の値）
    gender = current_user.gender || 'female'  # デフォルトは女性
    age = current_user.age || 30  # デフォルトは30歳
    
    if gender == 'male'
      {
        protein: 65,           # 男性の1日あたりのタンパク質推奨量（g）
        carbohydrates: 325,    # 男性の1日あたりの炭水化物推奨量（g）
        fat: 70,               # 男性の1日あたりの脂質推奨量（g）
        vitamins: 80,          # ビタミン目標値（％）
        minerals: 80           # ミネラル目標値（％）
      }
    else
      {
        protein: 50,           # 女性の1日あたりのタンパク質推奨量（g）
        carbohydrates: 250,    # 女性の1日あたりの炭水化物推奨量（g）
        fat: 60,               # 女性の1日あたりの脂質推奨量（g）
        vitamins: 80,          # ビタミン目標値（％）
        minerals: 80           # ミネラル目標値（％）
      }
    end
  end
end