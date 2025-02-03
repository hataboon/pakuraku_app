class StaticPagesController < ApplicationController
  def top
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.today
    @start_date = @date.beginning_of_month
    @end_date = @date.end_of_month

    # ログインユーザーの場合は自分の献立のみ、未ログインの場合は公開された献立を表示
    @calendar_plans = if user_signed_in?
      current_user.calendar_plans
        .includes(:recipe)
        .where(date: @start_date..@end_date)
        .order(date: :asc, meal_time: :asc)
    else
      CalendarPlan.includes(:recipe)
        .publicly_visible  # スコープを使用
        .where(date: @start_date..@end_date)
        .order(date: :asc, meal_time: :asc)
    end

    # 今日の献立を取得
    @todays_plans = @calendar_plans.select { |plan| plan.date == Date.today }
  end
end