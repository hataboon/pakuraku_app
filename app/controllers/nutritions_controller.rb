class NutritionsController < ApplicationController
  before_action :authenticate_user!

  def show
    @period = params[:period]
    @start_date = parse_date(params[:start_date], 1.month.ago.to_date)
    @end_date = parse_date(params[:end_date], Date.today)
    @nutrition_data = calculate_nutrition_data(@start_date, @end_date)

    respond_to do |format|
      format.html
      format.json { render json: @nutrition_data }
    end
  end

  private

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
      meal_plan = JSON.parse(plan.meal_plan)
      nutrients = meal_plan["nutrients"]

      # recipes_controllerと同じ計算方法を使用
      total_nutrients[:protein] += nutrients["protein"].to_s.scan(/\d+/).first&.to_i || 0
      total_nutrients[:carbohydrates] += nutrients["carbohydrates"].to_s.scan(/\d+/).first&.to_i || 0
      total_nutrients[:fat] += nutrients["fat"].to_s.scan(/\d+/).first&.to_i || 0
      total_nutrients[:vitamins] += calculate_nutrient_score(nutrients["vitamins"])
      total_nutrients[:minerals] += calculate_nutrient_score(nutrients["minerals"])
    end

    # 生の値をそのまま返す（推奨摂取量との比較は行わない）
    total_nutrients
  end

  def calculate_nutrient_score(nutrient_str)
    return 0 if nutrient_str.blank?
    count = nutrient_str.split(",").size
    [ count * 33, 100 ].min
  end
end
