class NutritionsController < ApplicationController
  before_action :authenticate_user!

  def show
    @period = params[:period] || 'daily'
    @nutrition_data = calculate_nutrition_data(@period)

    respond_to do |format|
      format.html
      format.json { render json: @nutrition_data }
    end
  end

  private

  def calculate_nutrition_data(period)
    plans = case period
    when 'monthly'
      CalendarPlan.where(user: current_user)
                 .where('date >= ?', 1.month.ago)
    when 'weekly'
      CalendarPlan.where(user: current_user)
                 .where('date >= ?', 1.week.ago)
    else
      CalendarPlan.where(user: current_user)
                 .where('date = ?', Date.today)
    end

    total_nutrients = {
      protein: 0,
      carbohydrates: 0,
      fat: 0,
      vitamins: 0,  # 複数形に統一
      minerals: 0   # 複数形に統一
    }

    plans.each do |plan|
      meal_plan = JSON.parse(plan.meal_plan)
      nutrients = meal_plan['nutrients']
      
      # タンパク質、炭水化物、脂質の計算
      total_nutrients[:protein] += normalize_gram_value(nutrients['protein'])
      total_nutrients[:carbohydrates] += normalize_gram_value(nutrients['carbohydrates'])
      total_nutrients[:fat] += normalize_gram_value(nutrients['fat'])
      
      # ビタミンとミネラルのスコア計算
      total_nutrients[:vitamins] += calculate_nutrient_score(nutrients['vitamins'])
      total_nutrients[:minerals] += calculate_nutrient_score(nutrients['minerals'])
    end

    # 1日の推奨摂取量
    daily_recommended = {
      protein: 60,         # 60g/日
      carbohydrates: 330,  # 330g/日
      fat: 60,            # 60g/日
      vitamins: 3,        # 最大3種類を想定
      minerals: 3         # 最大3種類を想定
    }

    # 割合に変換して返す
    {
      protein: normalize_percentage(total_nutrients[:protein], daily_recommended[:protein]),
      carbohydrates: normalize_percentage(total_nutrients[:carbohydrates], daily_recommended[:carbohydrates]),
      fat: normalize_percentage(total_nutrients[:fat], daily_recommended[:fat]),
      vitamins: normalize_percentage(total_nutrients[:vitamins], daily_recommended[:vitamins]),
      minerals: normalize_percentage(total_nutrients[:minerals], daily_recommended[:minerals])
    }
  end

  def normalize_gram_value(value)
    value.to_s.scan(/\d+/).first.to_i
  end

  def calculate_nutrient_score(nutrient_str)
    return 0 if nutrient_str.blank?
    count = nutrient_str.split(',').size
    # 3種類を最大として、1種類あたり33点で計算
    [count * 33, 100].min
  end

  def normalize_percentage(value, recommended)
    ((value.to_f / recommended) * 100).round(1)
  end
end