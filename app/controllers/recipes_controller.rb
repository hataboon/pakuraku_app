class RecipesController < ApplicationController
  include NutritionsHelper
  include ApplicationHelper

  before_action :authenticate_user!, except: [ :show ]
  before_action :set_date_range, only: [ :new, :show ]

  def new
    @start_date = @date.beginning_of_month
    @end_date = @date.end_of_month

    # カレンダー表示用のデータ取得
    @calendar_plans = CalendarPlan.where(user: current_user, date: @start_date..@end_date)

    @nutrients = %w[ミネラル たんぱく質 炭水化物 ビタミン 脂質]
    @q = current_user.calendar_plans.ransack(params[:q])
    @q.sorts = "created_at desc" if @q.sorts.empty?
    @search_results = params[:q].present? ? @q.result.includes(:recipe).page(params[:page]).per(12) : nil
  end

  def create
    # 必要なパラメーターを取得する
    main_nutrients = Array(params[:main_nutrients])
    side_nutrients = Array(params[:side_nutrients])
    category = params[:category].presence || "default"
    selected_dates = process_selected_dates(params[:selected_dates])

    # バリデーション
    if selected_dates.empty?
      redirect_to new_recipe_path, alert: "日付と時間帯を選択してください" and return
    end

    if main_nutrients.empty?
      redirect_to new_recipe_path, alert: "主菜の栄養素を1つ以上選択してください" and return
    end

    # セッションに保存
    session[:main_nutrients] = main_nutrients
    session[:side_nutrients] = side_nutrients
    session[:category] = category

    # レシピサービスの呼び出し
    recipe_service = RecipeService.new(current_user)

    begin
      generation_time = Time.current
      calendar_plans = recipe_service.create_meal_plans(selected_dates, main_nutrients, side_nutrients, category)

      if calendar_plans.present?
        # 日付をキーとして、その日に作成された献立を集計
        created_dates = calendar_plans.map { |cp| cp.date.to_s }.uniq
        redirect_to_recipe_page(created_dates, calendar_plans, generation_time)
      else
        redirect_to new_recipe_path, alert: "献立の生成に失敗しました。時間をおいて再度お試しください。"
      end
    rescue StandardError => e
      redirect_to new_recipe_path, alert: "献立の作成中にエラーが発生しました。時間をおいて再度お試しください。"
    end
  end

  def show
    base_date = params[:id]

    # all_datesパラメータがある場合は、それらの日付の献立も含める
    if params[:all_dates].present?
      all_dates = params[:all_dates].split(",")
      @calendar_plans = CalendarPlan.where(user: current_user, date: all_dates)
    else
      # 単一日付の場合（従来通り）
      @calendar_plans = CalendarPlan.where(user: current_user, date: base_date)
    end

    # 「作成せずに戻る」からのリクエストの場合
    if params[:cancel].present?
      cancel_meal_plan(base_date)
      return
    end

    if @calendar_plans.present?
      @share_text = generate_share_text(@calendar_plans.first)
      @share_url = request.base_url + recipe_path(params[:id])
      @parsed_meal_plans = parse_meal_plans(@calendar_plans)
    end
  end

  private

  def set_date_range
    @date = params[:date].present? ? Time.zone.parse(params[:date]).to_date : Time.zone.today
    @start_date = @date.beginning_of_month
    @end_date = @date.end_of_month
  end

  # 日付と時間帯の処理を行うメソッド
  def process_selected_dates(dates_params)
    selected_dates = {}
    return selected_dates unless dates_params.present?

    dates_hash = dates_params.to_unsafe_h
    dates_hash.each do |date_str, time_data|
      selected_times = []

      if time_data.is_a?(Hash)
        time_data.each { |time_name, value| selected_times << time_name if value == "1" }
      elsif time_data.is_a?(Array)
        selected_times = time_data
      end

      selected_dates[date_str] = selected_times if selected_times.any?
    end

    selected_dates
  end

  # 生成された献立ページへリダイレクト
  def redirect_to_recipe_page(created_dates, calendar_plans, generation_time)
    params = {
      id: created_dates.first,
      meal_time: calendar_plans.first.meal_time,
      generated_at: generation_time.iso8601
    }

    notice = "#{calendar_plans.size}件の献立を作成しました。"

    if created_dates.size > 1
      params[:all_dates] = created_dates.join(",")
      notice += "#{created_dates.size}日分の献立が含まれています。"
    end

    redirect_to recipe_path(params), notice: notice
  end

  # 献立作成のキャンセル処理
  def cancel_meal_plan(base_date)
    plan_to_delete = if params[:meal_time].present? && params[:generated_at].present?
      time_threshold = Time.zone.parse(params[:generated_at])
      CalendarPlan.where(
        user: current_user,
        date: base_date,
        meal_time: params[:meal_time]
      ).where("created_at >= ?", time_threshold).order(created_at: :desc).first
    else
      @calendar_plans.order(created_at: :desc).first
    end

    if plan_to_delete
      plan_to_delete.destroy
      redirect_to new_recipe_path, notice: "献立作成をキャンセルしました"
    else
      redirect_to new_recipe_path, alert: "キャンセルする献立が見つかりませんでした"
    end
  end

  # 献立のシェアテキストを生成するメソッド
  def generate_share_text(calendar_plan)
    plan = JSON.parse(calendar_plan.meal_plan)
    time_mapping = { "morning" => "朝食", "afternoon" => "昼食", "evening" => "夕食" }
    meal_time = time_mapping[calendar_plan.meal_time&.downcase] || "食事"

    text = "【#{meal_time}の献立】\n主菜：#{plan['main']}\n副菜：#{plan['side']}\n"
    text += "#{plan['soup']}\n" if plan["soup"].present?
    text += "\n#パクラク #献立 #料理"

    ERB::Util.url_encode(text)
  end

  def parse_meal_plans(calendar_plans)
    nutrition_service = NutritionCalculationService.new
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

        protein = nutrients[:protein].to_s.gsub(/[^\d.]/, "").to_f
        fat = nutrients[:fat].to_s.gsub(/[^\d.]/, "").to_f
        carbs = nutrients[:carbohydrates].to_s.gsub(/[^\d.]/, "").to_f

        vitamins_score = calculate_vitamins_score(nutrients[:vitamins])
        minerals_score = calculate_minerals_score(nutrients[:minerals])

        chart_data = {
          values: { protein: protein, carbohydrates: carbs, fat: fat },
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
        nil
      end
    end.compact
  end

  def calculate_vitamins_score(vitamins)
    return 0 unless vitamins.is_a?(Array)

    weights = {
      "ビタミンA" => 25, "ビタミンD" => 20, "ビタミンB1" => 15,
      "ビタミンB2" => 15, "ビタミンC" => 25
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
      "鉄" => 30, "カルシウム" => 30, "マグネシウム" => 20, "亜鉛" => 20
    }

    total_score = 0
    minerals.each do |mineral|
      weight = weights.find { |k, _| mineral.include?(k) }&.last || 10
      total_score += weight
    end

    [ total_score, 100 ].min
  end
end
