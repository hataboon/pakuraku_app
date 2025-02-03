class FoodsController < ApplicationController
  def index
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
        .where(public: true)
        .where(date: @start_date..@end_date)
        .order(date: :asc, meal_time: :asc)
    end

    # 今日の献立を取得
    @todays_plans = @calendar_plans.select { |plan| plan.date == Date.today }

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "calendar",
          partial: "calendar_content",
          locals: { date: @date, calendar_plans: @calendar_plans }
        )
      end
    end
  end
end
