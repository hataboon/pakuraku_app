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
end
