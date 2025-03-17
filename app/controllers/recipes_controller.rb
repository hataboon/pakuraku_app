class RecipesController < ApplicationController
  include NutritionsHelper
  include ApplicationHelper

  before_action :authenticate_user!, except: [ :show ]
  before_action :set_date_range, only: [ :new, :show ]

  def new
    # カレンダー表示用のデータ取得
    @calendar_plans = CalendarPlan.where(user: current_user, date: @start_date..@end_date)
    Rails.logger.debug "Total calendar plans: #{@calendar_plans.count}"
    @calendar_plans.each do |plan|
      Rails.logger.debug "Plan: date=#{plan.date}, meal_time=#{plan.meal_time}, meal_plan=#{plan.meal_plan}"
    end
    @nutrients = %w[ミネラル たんぱく質 炭水化物 ビタミン 脂質]
    @q = current_user.calendar_plans.ransack(params[:q])
    @q.sorts = "created_at desc" if @q.sorts.empty?
    @search_results = if params[:q].present?
      @q.result.includes(:recipe).page(params[:page]).per(12)
    else
      nil
    end
  end

  def create
    Rails.logger.debug "フォーム送信パラメータ: #{params.inspect}"

    # 1. 必要なパラメーターを取得する
    main_nutrients = Array(params[:main_nutrients])
    side_nutrients = Array(params[:side_nutrients])
    category = params[:category].presence || "default"

    # 2. 日付と時間帯の処理
    selected_dates = {}

    if params[:selected_dates].present?
      dates_hash = params[:selected_dates].to_unsafe_h

      # 各日付を処理する
      dates_hash.each do |date_str, time_data|
        selected_times = []

        # 時間帯データの形式に応じた処理
        if time_data.is_a?(Hash)
          # 通常のフォーム送信形式: {"morning"=>"1"}
          time_data.each do |time_name, value|
            Rails.logger.debug "  チェック: #{time_name} => #{value}"
            if value == "1"
              selected_times << time_name
            end
          end
        elsif time_data.is_a?(Array)
          selected_times = time_data
        end

        # 選択された時間帯があれば、日付とともに保存する
        if selected_times.any?
          selected_dates[date_str] = selected_times
          Rails.logger.debug "この日付を追加しました: #{date_str} => #{selected_times.inspect}"
        end
      end
    end

    # バリデーション
    if selected_dates.empty?
      Rails.logger.debug "エラー: 日付が選択されていません"
      redirect_to new_recipe_path, alert: "日付と時間帯を選択してください" and return
    end

    if main_nutrients.empty?
      Rails.logger.debug "エラー: 主菜栄養素が選択されていません"
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

      calendar_plans = recipe_service.create_meal_plans(
        selected_dates,
        main_nutrients,
        side_nutrients,
        category
      )

      if calendar_plans.present?
        Rails.logger.debug "献立作成成功: #{calendar_plans.size}件の献立を作成"

        # 日付をキーとして、その日に作成された献立を集計
        created_dates = calendar_plans.map { |cp| cp.date.to_s }.uniq
        if created_dates.size == 1
          # 1つの日付だけの場合、その日付のshowページへリダイレクト
          redirect_to recipe_path(
            id: created_dates.first,
            meal_time: calendar_plans.first.meal_time,
            generated_at: generation_time.iso8601
          ),
          notice: "#{calendar_plans.size}件の献立を作成しました。"
        else
          # 複数の日付にまたがる場合
          redirect_to recipe_path(
            id: created_dates.first,
            all_dates: created_dates.join(","),
            meal_time: calendar_plans.first.meal_time,
            generated_at: generation_time.iso8601
          ),
          notice: "#{calendar_plans.size}件の献立を作成しました。#{created_dates.size}日分の献立が含まれています。"
        end
      else
        Rails.logger.debug "献立作成失敗: 生成された献立がありません"
        redirect_to new_recipe_path,
                    alert: "献立の生成に失敗しました。時間をおいて再度お試しください。"
      end
    rescue StandardError => e
      Rails.logger.error("献立作成エラー: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      redirect_to new_recipe_path,
                  alert: "献立の作成中にエラーが発生しました。時間をおいて再度お試しください。"
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

    # デバッグ用ログ
    Rails.logger.debug "Calendar plans found: #{@calendar_plans.size}"
    @calendar_plans.each do |plan|
      Rails.logger.debug "Plan ID: #{plan.id}, meal_time: #{plan.meal_time.inspect} (#{plan.meal_time.class})"
    end

    # 「作成せずに戻る」からのリクエストの場合
    if params[:cancel].present?
      # cancelボタンが押された場合、最後に生成された献立を特定して削除
      # 日付と時間帯の両方を考慮してフィルタリング
      if params[:meal_time].present? && params[:generated_at].present?
        # 指定された日付、時間帯、生成時間に基づいて献立を削除
        time_threshold = Time.zone.parse(params[:generated_at])
        matching_plan = CalendarPlan.where(
          user: current_user,
          date: base_date,
          meal_time: params[:meal_time]
        ).where("created_at >= ?", time_threshold).order(created_at: :desc).first

        if matching_plan
          matching_plan.destroy
          redirect_to new_recipe_path, notice: "献立作成をキャンセルしました" and return
        else
          redirect_to new_recipe_path, alert: "キャンセルする献立が見つかりませんでした" and return
        end
      else
        latest_plan = @calendar_plans.order(created_at: :desc).first
        if latest_plan
          latest_plan.destroy
          redirect_to new_recipe_path, notice: "献立作成をキャンセルしました" and return
        else
          redirect_to new_recipe_path, alert: "キャンセルする献立が見つかりませんでした" and return
        end
      end
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

    # 修正部分: 月の最初と最後の日から、週の始め（日曜日）と終わり（土曜日）を計算
    @start_date = @date.beginning_of_month.beginning_of_week(:sunday)
    @end_date = @date.end_of_month.end_of_week(:sunday)
  end

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
    meal_time = time_mapping[calendar_plan.meal_time&.downcase] || "食事"

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
