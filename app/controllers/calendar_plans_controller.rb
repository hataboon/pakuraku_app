class CalendarPlansController < ApplicationController
  before_action :authenticate_user! # Devise を使用している場合

  def index
    # ログイン中のユーザーが所有する献立だけ取得
    @calendar_plans = current_user.calendar_plans
  end

  def destroy
    @calendar_plan = CalendarPlan.find_by(id: params[:id])

    if @calendar_plan && @calendar_plan.user_id == current_user.id
      @calendar_plan.destroy
      flash[:success] = "献立が削除されました。"
    else
      flash[:error] = "削除権限がありません。"
    end

    redirect_back fallback_location: root_path
  end

  def reuse
    # パラメータを取得
    calendar_plan_id = params[:calendar_plan_id]
    date = params[:date]
    meal_time = params[:meal_time]

    # 元の献立プラン取得
    original_plan = CalendarPlan.find(calendar_plan_id)

    # アクセス権限チェック
    unless original_plan.user_id == current_user.id
      return render json: { success: false, error: "権限がありません" }, status: :forbidden
    end

    # 既存の献立をチェック（同じ日付・時間帯に既に献立がある場合は削除）
    existing_plan = current_user.calendar_plans.find_by(
      date: date,
      meal_time: meal_time
    )
    existing_plan&.destroy

    # 新しい献立プランを作成
    new_plan = CalendarPlan.new(
      user_id: current_user.id,
      recipe_id: original_plan.recipe_id,
      date: date,
      meal_time: meal_time,
      meal_plan: original_plan.meal_plan
    )

    if new_plan.save
      render json: { success: true, reload: true }
    else
      render json: { success: false, error: new_plan.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end
end
